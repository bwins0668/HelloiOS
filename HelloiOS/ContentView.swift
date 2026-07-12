import SwiftUI
import Combine

// MARK: - Theme

private enum RouletteTheme {
    static let bg = Color(red: 0.05, green: 0.03, blue: 0.06)
    static let panel = Color(red: 0.11, green: 0.07, blue: 0.12)
    static let panelStroke = Color(red: 0.22, green: 0.14, blue: 0.25)
    static let gold = Color(red: 1.0, green: 0.82, blue: 0.22)
    static let goldDim = Color(red: 0.8, green: 0.6, blue: 0.15)
    static let red = Color(red: 0.95, green: 0.22, blue: 0.28)
    static let redGlow = Color(red: 1.0, green: 0.35, blue: 0.35)
    static let green = Color(red: 0.22, green: 0.85, blue: 0.45)
    static let text = Color.white
    static let textDim = Color.white.opacity(0.55)
    static let demon = Color(red: 0.65, green: 0.15, blue: 0.75)
    static let demonGlow = Color(red: 0.9, green: 0.3, blue: 1.0)
}

// MARK: - Models

private enum Shell: Equatable {
    case live
    case blank
}

private enum Turn: Equatable {
    case player
    case demon
}

private enum GamePhase: Equatable {
    case menu
    case dealing    // animating shell reveal
    case playerTurn
    case demonTurn
    case roundEnd
    case gameOver
}

private enum ItemType: String, CaseIterable, Identifiable {
    case magnifier = "放大镜"
    case beer = "啤酒"
    case cuffs = "手铐"
    case saw = "手锯"
    case medicine = "药品"
    case inverter = "逆变器"
    case phone = "电话"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .magnifier: return "magnifyingglass"
        case .beer: return "wineglass"
        case .cuffs: return "handcuffs"
        case .saw: return "scissors"
        case .medicine: return "pills"
        case .inverter: return "arrow.triangle.2.circlepath"
        case .phone: return "phone"
        }
    }

    var color: Color {
        switch self {
        case .magnifier: return .cyan
        case .beer: return .orange
        case .cuffs: return .purple
        case .saw: return .red
        case .medicine: return .green
        case .inverter: return .pink
        case .phone: return .blue
        }
    }

    var description: String {
        switch self {
        case .magnifier: return "查看当前弹膛"
        case .beer: return "退出一发弹壳（随机）"
        case .cuffs: return "跳过恶魔下一回合"
        case .saw: return "霰弹枪伤害×2"
        case .medicine: return "治疗 1 点 或 扣 1 点（50%）"
        case .inverter: return "翻转当前弹膛"
        case .phone: return "得到一条提示"
        }
    }
}

private struct Item: Identifiable, Equatable {
    let id: UUID
    let type: ItemType
    var used: Bool = false
}

// MARK: - Engine

@MainActor
private final class RouletteEngine: ObservableObject {
    // State
    @Published var phase: GamePhase = .menu
    @Published var playerLives: Int = 4
    @Published var demonLives: Int = 4
    @Published var playerMaxLives: Int = 4
    @Published var demonMaxLives: Int = 4
    @Published var currentTurn: Turn = .player
    @Published var chamber: [Shell] = []
    @Published var chamberIndex: Int = 0
    @Published var knownShell: Shell? = nil
    @Published var playerItems: [Item] = []
    @Published var demonItems: [Item] = []
    @Published var sawActive: Bool = false
    @Published var cuffsActive: Bool = false
    @Published var inverterUsed: Bool = false
    @Published var log: [String] = []
    @Published var showMagnifier = false
    @Published var magnifierShell: Shell?
    @Published var phoneHint: String?

    // Round config
        @Published var round = 1
        private let maxRounds = 3
        private var shellsThisRound: Int = 0

    // AI
    private let rng = SystemRandomNumberGenerator()

    init() {}

    // MARK: Public API

    func start() {
        resetAll()
        phase = .dealing
        dealShells()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.phase = .playerTurn
            self.currentTurn = .player
            self.giveItems(round: 1)
            self.log("第 1 回合开始 · 你先手")
        }
    }

    func backToMenu() {
        phase = .menu
        log = []
    }

    func shootSelf() { fire(atSelf: true) }
    func shootDemon() { fire(atSelf: false) }

    func useItem(_ item: Item) {
        guard phase == .playerTurn, !item.used else { return }
        guard let idx = playerItems.firstIndex(where: { $0.id == item.id }) else { return }

        switch item.type {
        case .magnifier:
            if chamberIndex < chamber.count {
                knownShell = chamber[chamberIndex]
                showMagnifier = true
                magnifierShell = knownShell
                log("🔍 放大镜：这是 \(knownShell == .live ? "实弹" : "空包弹")")
            }
        case .beer:
            if chamberIndex < chamber.count {
                let ejected = chamber.remove(at: chamberIndex)
                log("🍺 啤酒：退出 \(ejected == .live ? "实弹" : "空包弹")")
                if chamber.isEmpty { endRound() }
            }
        case .cuffs:
            cuffsActive = true
            log("🔒 手铐：恶魔下一回合被跳过")
        case .saw:
            sawActive = true
            log("🪚 手锯：本回合伤害翻倍")
        case .medicine:
            let heal = Bool.random()
            if heal {
                playerLives = min(playerMaxLives, playerLives + 1)
                log("💊 药品：治疗 1 点")
            } else {
                playerLives = max(1, playerLives - 1)
                log("💊 药品：副作用，扣 1 点")
            }
        case .inverter:
            if chamberIndex < chamber.count {
                chamber[chamberIndex] = chamber[chamberIndex] == .live ? .blank : .live
                knownShell = nil
                inverterUsed = true
                log("🔄 逆变器：翻转当前弹膛")
            }
        case .phone:
            // give a hint about a future shell
            if chamberIndex + 1 < chamber.count {
                let hint = chamber[chamberIndex + 1]
                phoneHint = "下一发是 \(hint == .live ? "实弹" : "空包弹")"
                log("📞 电话：\(phoneHint!)")
            }
        }
        playerItems[idx].used = true
        // end turn after item unless it's info-only
        if item.type != .magnifier && item.type != .phone {
            endPlayerTurn()
        }
    }

    func discardItem(_ item: Item) {
        guard let idx = playerItems.firstIndex(where: { $0.id == item.id }) else { return }
        playerItems.remove(at: idx)
        log("丢弃 \(item.type.rawValue)")
    }

    // MARK: Core Logic

    private func dealShells() {
        let liveCount: Int
        let blankCount: Int
        switch round {
        case 1: (liveCount, blankCount) = (2, 2)
        case 2: (liveCount, blankCount) = (3, 2)
        case 3: (liveCount, blankCount) = (4, 3)
        default: (liveCount, blankCount) = (4, 3)
        }
        var shells: [Shell] = Array(repeating: .live, count: liveCount) + Array(repeating: .blank, count: blankCount)
        shells.shuffle()
        chamber = shells
        chamberIndex = 0
        shellsThisRound = shells.count
        knownShell = nil
        inverterUsed = false
        log("装填完成：\(liveCount) 实弹 / \(blankCount) 空包弹")
    }

    private func fire(atSelf: Bool) {
        guard phase == .playerTurn || phase == .demonTurn else { return }
        guard chamberIndex < chamber.count else { endRound(); return }

        let shell = chamber[chamberIndex]
        let isLive = shell == .live
        let damage = sawActive ? 2 : 1

        if atSelf {
            if isLive {
                if currentTurn == .player {
                    playerLives -= damage
                    log("💥 对自己开枪 · 实弹 · 扣 \(damage) 血")
                } else {
                    demonLives -= damage
                    log("💥 恶魔对自己开枪 · 实弹 · 扣 \(damage) 血")
                }
            } else {
                log("💨 对自己开枪 · 空包弹 · 安全")
                // extra turn
                if currentTurn == .player {
                    log("→ 空包弹，你获得额外回合")
                    chamberIndex += 1
                    if chamberIndex >= chamber.count { endRound(); return }
                    return
                } else {
                    log("→ 空包弹，恶魔获得额外回合")
                    chamberIndex += 1
                    if chamberIndex >= chamber.count { endRound(); return }
                    demonAct()
                    return
                }
            }
        } else {
            if isLive {
                if currentTurn == .player {
                    demonLives -= damage
                    log("💥 对恶魔开枪 · 实弹 · 恶魔扣 \(damage) 血")
                } else {
                    playerLives -= damage
                    log("💥 恶魔对你开枪 · 实弹 · 你扣 \(damage) 血")
                }
            } else {
                log("💨 对恶魔开枪 · 空包弹 · 无事发生")
            }
        }

        sawActive = false
        chamberIndex += 1
        knownShell = nil
        inverterUsed = false
        phoneHint = nil

        checkDeath()
        if phase == .gameOver { return }

        if chamberIndex >= chamber.count {
            endRound()
        } else {
            switchTurn()
        }
    }

    private func switchTurn() {
        if currentTurn == .player {
            if cuffsActive {
                cuffsActive = false
                log("🔒 手铐生效：恶魔回合被跳过")
                // player goes again
                return
            }
            currentTurn = .demon
            phase = .demonTurn
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                self.demonAct()
            }
        } else {
            currentTurn = .player
            phase = .playerTurn
        }
    }

    private func demonAct() {
        guard phase == .demonTurn else { return }
        guard chamberIndex < chamber.count else { endRound(); return }

        // Simple AI: know probability, sometimes use items
        let remaining = chamber.count - chamberIndex
        let liveRemaining = chamber[chamberIndex...].filter { $0 == .live }.count
        let pLive = Double(liveRemaining) / Double(remaining)

        // occasionally use items if has any
        let availableItems = demonItems.enumerated().filter { !$0.element.used }.map { $0.offset }
        if !availableItems.isEmpty && Double.random(in: 0...1) < 0.25 {
            let idx = availableItems.randomElement()!
            useDemonItem(idx)
            return
        }

        // decide: shoot self if high chance blank, else shoot player
        let shootSelf = pLive < 0.45
        log("🤖 恶魔选择：\(shootSelf ? "对自己" : "对你")")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.fire(atSelf: shootSelf)
        }
    }

    private func useDemonItem(_ idx: Int) {
        let item = demonItems[idx]
        switch item.type {
        case .magnifier:
            knownShell = chamber[chamberIndex]
            log("🔍 恶魔用放大镜：知道了当前弹膛")
        case .beer:
            if chamberIndex < chamber.count {
                let ejected = chamber.remove(at: chamberIndex)
                log("🍺 恶魔喝啤酒：退出 \(ejected == .live ? "实弹" : "空包弹")")
                if chamber.isEmpty { endRound(); return }
            }
        case .cuffs:
            cuffsActive = true
            log("🔒 恶魔用手铐：你的下一回合被跳过")
        case .saw:
            sawActive = true
            log("🪚 恶魔用手锯：伤害翻倍")
        case .medicine:
            let heal = Bool.random()
            if heal {
                demonLives = min(demonMaxLives, demonLives + 1)
                log("💊 恶魔吃药：治疗 1 点")
            } else {
                demonLives = max(1, demonLives - 1)
                log("💊 恶魔吃药：副作用，扣 1 点")
            }
        case .inverter:
            if chamberIndex < chamber.count {
                chamber[chamberIndex] = chamber[chamberIndex] == .live ? .blank : .live
                knownShell = nil
                log("🔄 恶魔用逆变器：翻转弹膛")
            }
        case .phone:
            // skip
            break
        }
        demonItems[idx].used = true
        endPlayerTurn() // demon used item counts as turn
    }

    private func endPlayerTurn() {
        if currentTurn == .player {
            if cuffsActive {
                cuffsActive = false
                log("🔒 手铐生效：你的回合被跳过")
                currentTurn = .demon
                phase = .demonTurn
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { self.demonAct() }
            } else {
                currentTurn = .demon
                phase = .demonTurn
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { self.demonAct() }
            }
        }
    }

    private func checkDeath() {
        if playerLives <= 0 {
            phase = .gameOver
            log("☠️ 你死了 · 恶魔获胜")
        } else if demonLives <= 0 {
            phase = .gameOver
            log("🏆 恶魔死了 · 你获胜")
        }
    }

    private func endRound() {
        round += 1
        if round > maxRounds || playerLives <= 0 || demonLives <= 0 {
            if phase != .gameOver {
                phase = .gameOver
                log(playerLives > demonLives ? "🏆 全回合结束 · 你获胜" : "☠️ 全回合结束 · 恶魔获胜")
            }
            return
        }
        phase = .roundEnd
        log("第 \(round) 回合准备中...")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.startRound()
        }
    }

    private func startRound() {
        // heal 1 between rounds
        playerLives = min(playerMaxLives, playerLives + 1)
        demonLives = min(demonMaxLives, demonLives + 1)
        if round == 3 {
            playerMaxLives = 6
            demonMaxLives = 6
            playerLives = min(playerMaxLives, playerLives + 1)
            demonLives = min(demonMaxLives, demonLives + 1)
        }
        phase = .dealing
        dealShells()
        giveItems(round: round)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.currentTurn = .player
            self.phase = .playerTurn
            self.log("第 \(self.round) 回合开始 · 你先手")
        }
    }

    private func giveItems(round: Int) {
        let pool = ItemType.allCases
        let count = round == 1 ? 2 : round == 2 ? 3 : 4
        playerItems = (0..<count).map { _ in
            Item(id: UUID(), type: pool.randomElement()!)
        }
        demonItems = (0..<count).map { _ in
            Item(id: UUID(), type: pool.randomElement()!)
        }
    }

    private func resetAll() {
        round = 1
        playerLives = 4
        demonLives = 4
        playerMaxLives = 4
        demonMaxLives = 4
        chamber = []
        chamberIndex = 0
        knownShell = nil
        playerItems = []
        demonItems = []
        sawActive = false
        cuffsActive = false
        inverterUsed = false
        showMagnifier = false
        magnifierShell = nil
        phoneHint = nil
        log = []
    }

    private func log(_ s: String) {
        log.append(s)
        if log.count > 50 { log.removeFirst(log.count - 50) }
    }
}

// MARK: - View

struct ContentView: View {
    @StateObject private var game = RouletteEngine()
    @State private var pulse = false

    var body: some View {
        GeometryReader { geo in
            ZStack {
                background

                switch game.phase {
                case .menu:
                    menuLayer
                case .dealing:
                    dealingLayer
                case .playerTurn, .demonTurn:
                    playLayer(size: geo.size)
                case .roundEnd:
                    roundEndLayer
                case .gameOver:
                    ZStack {
                        playLayer(size: geo.size).opacity(0.2).blur(radius: 4)
                        gameOverLayer
                    }
                }
            }
            .onAppear {
                withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            RouletteTheme.bg.ignoresSafeArea()

            // pentagram glow
            Image(systemName: "circle.hexagongrid.fill")
                .font(.system(size: 320))
                .foregroundStyle(RouletteTheme.demon.opacity(pulse ? 0.08 : 0.04))
                .rotationEffect(.degrees(pulse ? 3 : -3))
                .animation(.easeInOut(duration: 4).repeatForever(autoreverses: true), value: pulse)
                .offset(y: -60)

            // corner candles
            ForEach(0..<4) { i in
                Circle()
                    .fill(RouletteTheme.gold.opacity(0.12))
                    .frame(width: 120, height: 120)
                    .blur(radius: 40)
                    .offset(x: i % 2 == 0 ? -160 : 160, y: i < 2 ? -300 : 300)
            }
        }
    }

    // MARK: Menu

    private var menuLayer: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .strokeBorder(
                            AngularGradient(
                                colors: [RouletteTheme.demon, RouletteTheme.red, RouletteTheme.gold, RouletteTheme.demon],
                                center: .center
                            ),
                            lineWidth: 4
                        )
                        .frame(width: 120, height: 120)
                        .rotationEffect(.degrees(pulse ? 180 : -180))
                        .animation(.linear(duration: 8).repeatForever(autoreverses: false), value: pulse)

                    Image(systemName: "scope")
                        .font(.system(size: 48, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [RouletteTheme.red, RouletteTheme.demon],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: RouletteTheme.redGlow.opacity(0.6), radius: 16)
                }

                Text("恶魔轮盘")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("与恶魔对赌 · 霰弹枪 · 实弹空包随机")
                    .font(.subheadline)
                    .foregroundStyle(RouletteTheme.textDim)
            }

            // rules preview
            VStack(alignment: .leading, spacing: 8) {
                ruleRow("🔴 实弹 = 扣血", RouletteTheme.red)
                ruleRow("⚪ 空包 = 安全 + 额外回合", RouletteTheme.green)
                ruleRow("🔫 对自己/对恶魔 任选", .white)
                ruleRow("🎒 每回合获得道具", RouletteTheme.gold)
                ruleRow("🏆 扣光恶魔血量获胜", RouletteTheme.green)
            }
            .font(.caption)
            .padding(16)
            .frame(maxWidth: 320)
            .background(RouletteTheme.panel, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(RouletteTheme.panelStroke, lineWidth: 1)
            )

            Button(action: game.start) {
                Text("开始对决")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [RouletteTheme.red, RouletteTheme.demon],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .shadow(color: RouletteTheme.redGlow.opacity(0.4), radius: 18, y: 8)
            }
            .padding(.horizontal, 44)

            Spacer()
            Text("v1.3 · 本地签名真机版")
                .font(.caption2)
                .foregroundStyle(RouletteTheme.textDim)
                .padding(.bottom, 16)
        }
        .padding()
    }

    private func ruleRow(_ t: String, _ c: Color) -> some View {
        HStack(spacing: 10) {
            Circle().fill(c).frame(width: 8, height: 8)
            Text(t).foregroundStyle(RouletteTheme.textDim)
        }
    }

    // MARK: Dealing

    private var dealingLayer: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                // shotgun silhouette
                Image(systemName: "scope")
                    .font(.system(size: 100, weight: .ultraLight))
                    .foregroundStyle(RouletteTheme.red.opacity(0.3))
                    .rotationEffect(.degrees(pulse ? 5 : -5))

                // shells animating
                ForEach(0..<game.chamber.count, id: \.self) { i in
                    let angle = Double(i) * 360 / Double(game.chamber.count) + (pulse ? 180 : 0)
                    Circle()
                        .fill(game.chamber[i] == .live ? RouletteTheme.red : RouletteTheme.green)
                        .frame(width: 22, height: 22)
                        .offset(x: cos(angle * .pi / 180) * 80, y: sin(angle * .pi / 180) * 80)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true).delay(Double(i) * 0.1), value: pulse)
                }
            }

            Text("装填中...")
                .font(.title2.weight(.medium))
                .foregroundStyle(RouletteTheme.gold)

            Text("第 \(game.round) 回合 · \(game.chamber.filter { $0 == .live }.count) 实弹 / \(game.chamber.filter { $0 == .blank }.count) 空包")
                .font(.subheadline)
                .foregroundStyle(RouletteTheme.textDim)

            Spacer()
        }
        .padding()
    }

    // MARK: Play

    private func playLayer(size: CGSize) -> some View {
        ZStack {
            // table
            VStack(spacing: 0) {
                // demon area
                demonArea
                    .frame(height: size.height * 0.38)

                // center: shotgun & chamber
                centerArea
                    .frame(height: size.height * 0.24)

                // player area
                playerArea
                    .frame(height: size.height * 0.38)
            }

            // magnifier popup
            if game.showMagnifier {
                Color.black.opacity(0.7).ignoresSafeArea()
                    .onTapGesture { game.showMagnifier = false }
                VStack(spacing: 16) {
                    Text(game.magnifierShell == .live ? "🔴 实弹" : "⚪ 空包弹")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(game.magnifierShell == .live ? RouletteTheme.red : RouletteTheme.green)
                    Button("知道了") { game.showMagnifier = false }
                        .font(.headline)
                        .padding(.horizontal, 32).padding(.vertical, 10)
                        .background(RouletteTheme.panel, in: Capsule())
                        .overlay(Capsule().stroke(RouletteTheme.panelStroke))
                }
                .padding(28)
                .background(RouletteTheme.panel, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(RouletteTheme.gold.opacity(0.5)))
                .transition(.scale.combined(with: .opacity))
            }

            // phone hint toast
            if let hint = game.phoneHint {
                VStack {
                    Spacer()
                    Text("📞 \(hint)")
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 20).padding(.vertical, 12)
                        .background(RouletteTheme.demon.opacity(0.9), in: Capsule())
                        .foregroundStyle(.white)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    Spacer().frame(height: 120)
                }
                .animation(.spring(), value: game.phoneHint)
            }
        }
    }

    // MARK: Areas

    private var demonArea: some View {
        VStack(spacing: 12) {
            HStack {
                Text("恶魔")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RouletteTheme.demon)
                Spacer()
                if game.cuffsActive && game.currentTurn == .player {
                    Label("被手铐", systemImage: "handcuffs")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RouletteTheme.gold)
                        .transition(.opacity)
                }
            }

            // lives
            HStack(spacing: 6) {
                ForEach(0..<game.demonMaxLives, id: \.self) { i in
                    ZStack {
                        Circle()
                            .strokeBorder(RouletteTheme.red.opacity(0.4), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        if i < game.demonLives {
                            Circle()
                                .fill(RouletteTheme.red)
                                .frame(width: 20, height: 20)
                                .transition(.scale)
                        }
                    }
                }
            }

            // demon items
            if !game.demonItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(game.demonItems) { item in
                            itemView(item, isPlayer: false)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            Spacer()

            // turn indicator
            if game.currentTurn == .demon && game.phase == .demonTurn {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.right.circle.fill")
                    Text("恶魔思考中...")
                }
                .font(.subheadline.weight(.medium))
                .foregroundStyle(RouletteTheme.demonGlow)
                .transition(.opacity)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RouletteTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 20).stroke(RouletteTheme.panelStroke)
                )
        )
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    private var playerArea: some View {
        VStack(spacing: 12) {
            HStack {
                Spacer()
                Text("你")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(RouletteTheme.gold)
                if game.cuffsActive && game.currentTurn == .demon {
                    Label("恶魔被手铐", systemImage: "handcuffs")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(RouletteTheme.gold)
                        .transition(.opacity)
                }
            }

            // lives
            HStack(spacing: 6) {
                ForEach(0..<game.playerMaxLives, id: \.self) { i in
                    ZStack {
                        Circle()
                            .strokeBorder(RouletteTheme.green.opacity(0.4), lineWidth: 2)
                            .frame(width: 28, height: 28)
                        if i < game.playerLives {
                            Circle()
                                .fill(RouletteTheme.green)
                                .frame(width: 20, height: 20)
                                .transition(.scale)
                        }
                    }
                }
            }

            // saw indicator
            if game.sawActive {
                Label("手锯生效 · 伤害×2", systemImage: "scissors")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(RouletteTheme.red)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Capsule().fill(RouletteTheme.red.opacity(0.15)))
                    .transition(.scale.combined(with: .opacity))
            }

            // player items
            if !game.playerItems.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(game.playerItems) { item in
                            itemView(item, isPlayer: true)
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }

            Spacer()

            // action buttons
            if game.phase == .playerTurn && game.chamberIndex < game.chamber.count {
                HStack(spacing: 16) {
                    // shoot self
                    Button(action: { game.shootSelf() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "person.fill")
                            Text("对自己")
                        }
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [RouletteTheme.green, RouletteTheme.green.opacity(0.7)], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundStyle(.white)
                    }

                    // shoot demon
                    Button(action: { game.shootDemon() }) {
                        VStack(spacing: 4) {
                            Image(systemName: "scope")
                            Text("对恶魔")
                        }
                        .font(.headline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(
                            LinearGradient(colors: [RouletteTheme.red, RouletteTheme.demon], startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                        .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(RouletteTheme.panel)
                .overlay(
                    RoundedRectangle(cornerRadius: 20).stroke(
                        game.phase == .playerTurn ? RouletteTheme.gold.opacity(0.5) : RouletteTheme.panelStroke
                    )
                )
        )
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private var centerArea: some View {
        VStack(spacing: 14) {
            // chamber display
            HStack(spacing: 8) {
                ForEach(game.chamber.indices, id: \.self) { i in
                    let shell = game.chamber[i]
                    let isCurrent = i == game.chamberIndex
                    let isKnown = game.knownShell != nil && i == game.chamberIndex
                    let isPast = i < game.chamberIndex

                    ZStack {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(
                                isPast ? Color.gray.opacity(0.3) :
                                isCurrent ? (isKnown ? (shell == .live ? RouletteTheme.red : RouletteTheme.green) : Color.white.opacity(0.15)) :
                                Color.white.opacity(0.08)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 10).stroke(
                                    isCurrent ? (isKnown ? (shell == .live ? RouletteTheme.red : RouletteTheme.green) : RouletteTheme.gold) : Color.clear,
                                    lineWidth: isCurrent ? 3 : 0
                                )
                            )
                            .frame(width: 44, height: 60)

                        if isPast || isKnown {
                            Image(systemName: shell == .live ? "circle.fill" : "circle")
                                .font(.system(size: 22, weight: shell == .live ? .bold : .light))
                                .foregroundStyle(shell == .live ? RouletteTheme.red : RouletteTheme.green)
                        } else if isCurrent {
                            Image(systemName: "questionmark")
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                                .symbolEffect(.pulse, options: .repeating)
                        } else {
                            Image(systemName: "circle")
                                .font(.system(size: 18, weight: .light))
                                .foregroundStyle(.white.opacity(0.25))
                        }
                    }
                    .animation(.spring(response: 0.3), value: game.chamberIndex)
                }
            }

            // shotgun visual
            ZStack {
                // barrel
                RoundedRectangle(cornerRadius: 6)
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.25), Color(white: 0.12)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .frame(width: 14, height: 70)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )

                // trigger guard
                Path { p in
                    p.move(to: CGPoint(x: -20, y: 20))
                    p.addArc(center: CGPoint(x: 0, y: 20), radius: 20, startAngle: .degrees(180), endAngle: .degrees(360), clockwise: false)
                }
                .stroke(Color.white.opacity(0.15), lineWidth: 3)
                .frame(width: 40, height: 40)
                .offset(y: 35)
            }
            .shadow(color: .black.opacity(0.5), radius: 8, y: 4)

            // round / log
            HStack(spacing: 16) {
                Label("第 \(game.round)/3 回合", systemImage: "number.circle")
                Label("剩余 \(game.chamber.count - game.chamberIndex) 发", systemImage: "cartridge")
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(RouletteTheme.textDim)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(RouletteTheme.panel.opacity(0.8))
        )
        .padding(.horizontal, 16)
    }

    private func itemView(_ item: Item, isPlayer: Bool) -> some View {
        let canUse = isPlayer && game.phase == .playerTurn && !item.used
        return Button(action: {
            if canUse { game.useItem(item) }
        }) {
            VStack(spacing: 4) {
                Image(systemName: item.type.icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(item.type.color)
                Text(item.type.rawValue)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(item.used ? 0.3 : 0.8))
                    .lineLimit(1)
            }
            .frame(width: 56, height: 56)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(item.used ? Color.gray.opacity(0.2) : (isPlayer ? item.type.color.opacity(0.15) : item.type.color.opacity(0.1)))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12).stroke(
                            item.used ? Color.clear : (isPlayer ? item.type.color.opacity(0.4) : item.type.color.opacity(0.3)),
                            lineWidth: 1
                        )
                    )
            )
            .opacity(item.used ? 0.5 : 1)
            .scaleEffect(canUse ? 1.0 : 0.95)
        }
        .buttonStyle(.plain)
        .disabled(!canUse)
        .contextMenu {
            if isPlayer && !item.used {
                Button("丢弃", role: .destructive) { game.discardItem(item) }
            }
        }
    }

    // MARK: Round End

    private var roundEndLayer: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("第 \(game.round - 1) 回合结束")
                .font(.title.weight(.bold))
                .foregroundStyle(RouletteTheme.gold)
            Text("恢复 1 血 · 重新装填 · 获得新道具")
                .foregroundStyle(RouletteTheme.textDim)
            Spacer()
        }
    }

    // MARK: Game Over

    private var gameOverLayer: some View {
        VStack(spacing: 22) {
            Spacer()

            let won = game.playerLives > 0 && game.demonLives <= 0
            ZStack {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: won ? [RouletteTheme.gold, RouletteTheme.green, RouletteTheme.gold] : [RouletteTheme.red, RouletteTheme.demon, RouletteTheme.red],
                            center: .center
                        ),
                        lineWidth: 6
                    )
                    .frame(width: 160, height: 160)
                    .rotationEffect(.degrees(pulse ? 360 : 0))
                    .animation(won ? .linear(duration: 3).repeatForever(autoreverses: false) : .easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulse)

                Image(systemName: won ? "crown.fill" : "skull.fill")
                    .font(.system(size: 64, weight: won ? .bold : .regular))
                    .foregroundStyle(won ? RouletteTheme.gold : RouletteTheme.red)
            }

            Text(won ? "你战胜了恶魔" : "恶魔赢了")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(won ? RouletteTheme.gold : RouletteTheme.red)

            VStack(spacing: 10) {
                statRow("你的剩余血量", "\(game.playerLives)")
                statRow("恶魔剩余血量", "\(game.demonLives)")
                statRow("回合", "\(min(game.round, 3))/3")
            }
            .padding(20)
            .frame(maxWidth: 300)
            .background(RouletteTheme.panel, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22).stroke(RouletteTheme.panelStroke))

            VStack(spacing: 12) {
                Button(action: game.start) {
                    Text(won ? "再战一次" : "复仇")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: won ? [RouletteTheme.gold, RouletteTheme.orange] : [RouletteTheme.red, RouletteTheme.demon], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
                Button("返回首页", action: game.backToMenu)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(RouletteTheme.textDim)
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .padding()
    }

    private func statRow(_ t: String, _ v: String) -> some View {
        HStack {
            Text(t).foregroundStyle(RouletteTheme.textDim)
            Spacer()
            Text(v).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
        }
    }
}

#Preview {
    ContentView()
}