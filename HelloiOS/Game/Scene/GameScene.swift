// Game/Models/Items.swift
import Foundation

enum ItemType: String, CaseIterable, Identifiable {
    case magnifier = "magnifier"
    case beer = "beer"
    case handcuffs = "handcuffs"
    case handsaw = "handsaw"
    case medicine = "medicine"
    case inverter = "inverter"
    case phone = "phone"
    case adrenaline = "adrenaline"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .magnifier: return "放大镜"
        case .beer: return "啤酒"
        case .handcuffs: return "手铐"
        case .handsaw: return "手锯"
        case .medicine: return "药品"
        case .inverter: return "逆变器"
        case .phone: return "电话"
        case .adrenaline: return "肾上腺素"
        }
    }
    
    var iconName: String {
        switch self {
        case .magnifier: return "🔍"
        case .beer: return "🍺"
        case .handcuffs: return "🔗"
        case .handsaw: return "🪚"
        case .medicine: return "💊"
        case .inverter: return "🔄"
        case .phone: return "📞"
        case .adrenaline: return "💉"
        }
    }
    
    var color: UInt32 {
        switch self {
        case .magnifier: return 0x00FFFF
        case .beer: return 0xFFB800
        case .handcuffs: return 0xAA44FF
        case .handsaw: return 0xFF4444
        case .medicine: return 0x44FF88
        case .inverter: return 0xFF66FF
        case .phone: return 0x4488FF
        case .adrenaline: return 0xFF22AA
        }
    }
    
    var description: String {
        switch self {
        case .magnifier: return "查看当前弹膛的弹种"
        case .beer: return "退出当前弹壳（随机）"
        case .handcuffs: return "跳过对手下一回合"
        case .handsaw: return "本回合伤害翻倍（2点）"
        case .medicine: return "治疗1点或受伤1点（50/50）"
        case .inverter: return "反转当前弹膛（实弹↔空包）"
        case .phone: return "获得一条提示"
        case .adrenaline: return "偷走对手一件未使用的道具"
        }
    }
    
    // Weight for random distribution (higher = more common)
    var spawnWeight: Int {
        switch self {
        case .magnifier: return 10
        case .beer: return 12
        case .handcuffs: return 8
        case .handsaw: return 8
        case .medicine: return 10
        case .inverter: return 6
        case .phone: return 6
        case .adrenaline: return 4
        }
    }
}

struct Item: Identifiable, Equatable {
    let id = UUID()
    let type: ItemType
    var used: Bool = false
    
    static func randomSet(count: Int) -> [Item] {
        var pool: [ItemType] = []
        for type in ItemType.allCases {
            pool += Array(repeating: type, count: type.spawnWeight)
        }
        pool.shuffle()
        return (0..<count).map { Item(type: pool[$0]) }
    }
}

// Game/Models/Shell.swift
enum ShellType: Equatable {
    case live
    case blank
    
    var isLive: Bool { self == .live }
    var displayName: String { isLive ? "实弹" : "空包弹" }
    var color: UInt32 { isLive ? 0xFF2222 : 0xDDDD33 }
}

// Game/Models/RoundConfig.swift
struct RoundConfig {
    let round: Int
    let liveCount: Int
    let blankCount: Int
    let maxLives: Int
    let startingItems: Int
    
    static let rounds: [RoundConfig] = [
        RoundConfig(round: 1, liveCount: 2, blankCount: 2, maxLives: 4, startingItems: 2),
        RoundConfig(round: 2, liveCount: 3, blankCount: 2, maxLives: 5, startingItems: 3),
        RoundConfig(round: 3, liveCount: 4, blankCount: 3, maxLives: 6, startingItems: 4)
    ]
    
    var totalShells: Int { liveCount + blankCount }
    var liveRatio: Double { Double(liveCount) / Double(totalShells) }
}

// Game/Models/GameState.swift
import Foundation
import Combine

class GameState: ObservableObject {
    @Published var phase: GamePhase = .menu
    @Published var currentRound: Int = 1
    @Published var playerLives: Int = 4
    @Published var dealerLives: Int = 4
    @Published var playerMaxLives: Int = 4
    @Published var dealerMaxLives: Int = 4
    @Published var playerItems: [Item] = []
    @Published var dealerItems: [Item] = []
    @Published var shells: [ShellType] = []
    @Published var currentShellIndex: Int = 0
    @Published var knownShell: ShellType? = nil
    @Published var currentTurn: Turn = .player
    @Published var sawActive: Bool = false
    @Published var handcuffsActive: Bool = false
    @Published var handcuffsTarget: Turn? = nil
    @Published var log: [String] = []
    @Published var magnifierShell: ShellType? = nil
    @Published var phoneHint: String? = nil
    @Published var dealerMood: DealerNode.Mood = .neutral
    @Published var dealerSpeech: String? = nil
    
    enum GamePhase: Equatable {
        case menu
        case dealing
        case playerTurn
        case dealerTurn
        case roundEnd
        case gameOver
    }
    
    enum Turn: Equatable {
        case player
        case dealer
    }
    
    var config: RoundConfig { RoundConfig.rounds[min(currentRound - 1, 2)] }
    var shellsRemaining: Int { shells.count - currentShellIndex }
    var isRoundOver: Bool { currentShellIndex >= shells.count }
    var isGameOver: Bool { playerLives <= 0 || dealerLives <= 0 }
    var winner: Turn? {
        if playerLives <= 0 { return .dealer }
        if dealerLives <= 0 { return .player }
        return nil
    }
    
    private var rng = SystemRandomNumberGenerator()
    
    func startNewGame() {
        currentRound = 1
        playerLives = config.maxLives
        dealerLives = config.maxLives
        playerMaxLives = config.maxLives
        dealerMaxLives = config.maxLives
        phase = .dealing
        log = []
        startRound()
    }
    
    func startRound() {
        phase = .dealing
        shells = generateShells()
        currentShellIndex = 0
        knownShell = nil
        sawActive = false
        handcuffsActive = false
        handcuffsTarget = nil
        magnifierShell = nil
        phoneHint = nil
        
        playerItems = Item.randomSet(count: config.startingItems)
        dealerItems = Item.randomSet(count: config.startingItems)
        
        log("第 \(currentRound) 回合开始 · \(config.liveCount) 实弹 / \(config.blankCount) 空包弹")
        log("你获得道具：\(playerItems.map { $0.type.displayName }.joined(separator: "、"))")
    }
    
    private func generateShells() -> [ShellType] {
        var result = Array(repeating: ShellType.live, count: config.liveCount) +
                     Array(repeating: ShellType.blank, count: config.blankCount)
        result.shuffle(using: &rng)
        return result
    }
    
    func advanceToPlaying() {
        currentTurn = .player
        phase = .playerTurn
        dealerMood = .neutral
        log("你先手")
    }
    
    func fire(atSelf: Bool) {
        guard currentShellIndex < shells.count else { endRound(); return }
        let shell = shells[currentShellIndex]
        let isLive = shell.isLive
        let damage = sawActive ? 2 : 1
        
        if atSelf {
            if isLive {
                if currentTurn == .player {
                    playerLives -= damage
                    log("💥 对自己开枪 · 实弹 · 扣 \(damage) 血")
                } else {
                    dealerLives -= damage
                    log("💥 恶魔对自己开枪 · 实弹 · 扣 \(damage) 血")
                    dealerMood = .surprised
                }
            } else {
                log("💨 对自己开枪 · 空包弹 · 安全")
                if currentTurn == .player {
                    log("→ 空包弹，你获得额外回合")
                } else {
                    log("→ 空包弹，恶魔获得额外回合")
                }
            }
        } else {
            if isLive {
                if currentTurn == .player {
                    dealerLives -= damage
                    log("💥 对恶魔开枪 · 实弹 · 恶魔扣 \(damage) 血")
                    dealerMood = .annoyed
                } else {
                    playerLives -= damage
                    log("💥 恶魔对你开枪 · 实弹 · 你扣 \(damage) 血")
                }
            } else {
                log("💨 对恶魔开枪 · 空包弹 · 无事发生")
            }
        }
        
        sawActive = false
        currentShellIndex += 1
        knownShell = nil
        phoneHint = nil
        
        checkDeath()
        if isGameOver {
            endGame()
            return
        }
        
        if isRoundOver {
            endRound()
        } else {
            switchTurn()
        }
    }
    
    func useItem(_ item: Item) {
        guard phase == .playerTurn, !item.used,
              let idx = playerItems.firstIndex(where: { $0.id == item.id }) else { return }
        
        switch item.type {
        case .magnifier:
            if currentShellIndex < shells.count {
                knownShell = shells[currentShellIndex]
                magnifierShell = knownShell
                log("🔍 放大镜：当前是 \(knownShell!.displayName)")
            }
            
        case .beer:
            if currentShellIndex < shells.count {
                let ejected = shells.remove(at: currentShellIndex)
                log("🍺 啤酒：退出 \(ejected.displayName)")
                if shells.isEmpty { endRound(); return }
            }
            
        case .handcuffs:
            handcuffsActive = true
            handcuffsTarget = .dealer
            log("🔗 手铐：恶魔下一回合被跳过")
            
        case .handsaw:
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
            if currentShellIndex < shells.count {
                shells[currentShellIndex] = shells[currentShellIndex] == .live ? .blank : .live
                knownShell = nil
                log("🔄 逆变器：翻转当前弹膛")
            }
            
        case .phone:
            if currentShellIndex + 1 < shells.count {
                let hint = shells[currentShellIndex + 1]
                phoneHint = "下一发是 \(hint.displayName)"
                log("📞 电话：\(phoneHint!)")
            }
            
        case .adrenaline:
            let available = dealerItems.enumerated().filter { !$0.element.used }.map { $0.offset }
            if let idx = available.randomElement() {
                let stolen = dealerItems[idx]
                stolen.used = true // mark as used so dealer can't use it
                playerItems.append(stolen)
                log("💉 肾上腺素：偷走恶魔的 \(stolen.type.displayName)")
            } else {
                log("💉 肾上腺素：恶魔没有可偷的道具")
            }
        }
        
        playerItems[idx].used = true
        
        // Items that don't end turn
        if ![.magnifier, .phone].contains(item.type) {
            endPlayerTurn()
        }
    }
    
    func discardItem(_ item: Item) {
        playerItems.removeAll { $0.id == item.id }
        log("丢弃 \(item.type.displayName)")
    }
    
    private func endPlayerTurn() {
        if handcuffsActive && handcuffsTarget == .player {
            handcuffsActive = false
            handcuffsTarget = nil
            log("🔗 手铐生效：你的回合被跳过")
            currentTurn = .dealer
            phase = .dealerTurn
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.dealerAct() }
        } else {
            currentTurn = .dealer
            phase = .dealerTurn
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.dealerAct() }
        }
    }
    
    private func switchTurn() {
        if currentTurn == .player {
            if handcuffsActive && handcuffsTarget == .dealer {
                handcuffsActive = false
                handcuffsTarget = nil
                log("🔗 手铐生效：恶魔回合被跳过")
                return // Player goes again
            }
            currentTurn = .dealer
            phase = .dealerTurn
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { self.dealerAct() }
        } else {
            currentTurn = .player
            phase = .playerTurn
        }
    }
    
    private func dealerAct() {
        guard phase == .dealerTurn, currentShellIndex < shells.count else { return }
        
        let remaining = shells.count - currentShellIndex
        let liveRemaining = shells[currentShellIndex...].filter { $0 == .live }.count
        let pLive = Double(liveRemaining) / Double(remaining)
        
        // Decide whether to use item
        let availableItems = dealerItems.enumerated().filter { !$0.element.used }.map { $0.offset }
        if !availableItems.isEmpty && Double.random(in: 0...1) < 0.2 {
            useDealerItem(availableItems.randomElement()!)
            return
        }
        
        // Decision logic
        let shootSelf = pLive < 0.45
        dealerMood = shootSelf ? .thinking : .amused
        dealerSpeech = shootSelf ? "我看这发是空包..." : "这发留给你吧。"
        
        log("🤖 恶魔选择：\(shootSelf ? "对自己" : "对你")")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.fire(atSelf: shootSelf)
        }
    }
    
    private func useDealerItem(_ idx: Int) {
        let item = dealerItems[idx]
        switch item.type {
        case .magnifier:
            knownShell = shells[currentShellIndex]
            log("🔍 恶魔用放大镜：知道了当前弹膛")
        case .beer:
            if currentShellIndex < shells.count {
                let ejected = shells.remove(at: currentShellIndex)
                log("🍺 恶魔喝啤酒：退出 \(ejected.displayName)")
                if shells.isEmpty { endRound(); return }
            }
        case .handcuffs:
            handcuffsActive = true
            handcuffsTarget = .player
            log("🔗 恶魔用手铐：你的下一回合被跳过")
        case .handsaw:
            sawActive = true
            log("🪚 恶魔用手锯：伤害翻倍")
        case .medicine:
            let heal = Bool.random()
            if heal {
                dealerLives = min(dealerMaxLives, dealerLives + 1)
                log("💊 恶魔吃药：治疗 1 点")
            } else {
                dealerLives = max(1, dealerLives - 1)
                log("💊 恶魔吃药：副作用，扣 1 点")
            }
        case .inverter:
            if currentShellIndex < shells.count {
                shells[currentShellIndex] = shells[currentShellIndex] == .live ? .blank : .live
                knownShell = nil
                log("🔄 恶魔用逆变器：翻转弹膛")
            }
        case .phone:
            break // skip
        case .adrenaline:
            let available = playerItems.enumerated().filter { !$0.element.used }.map { $0.offset }
            if let pIdx = available.randomElement() {
                let stolen = playerItems[pIdx]
                stolen.used = true
                dealerItems.append(stolen)
                log("💉 恶魔用肾上腺素：偷走你的 \(stolen.type.displayName)")
            }
        }
        
        dealerItems[idx].used = true
        endPlayerTurn() // dealer used item = turn ends
    }
    
    private func checkDeath() {
        if playerLives <= 0 || dealerLives <= 0 {
            phase = .gameOver
            let winner = playerLives > 0 ? "你" : "恶魔"
            log(winner == "你" ? "🏆 恶魔死了 · 你获胜" : "☠️ 你死了 · 恶魔获胜")
            dealerMood = winner == "你" ? .dead : .amused
        }
    }
    
    private func endRound() {
        currentRound += 1
        if currentRound > RoundConfig.rounds.count || isGameOver {
            if !isGameOver { phase = .gameOver }
            return
        }
        phase = .roundEnd
        log("第 \(currentRound - 1) 回合结束")
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            self.playerLives = min(self.playerMaxLives, self.playerLives + 1)
            self.dealerLives = min(self.dealerMaxLives, self.dealerLives + 1)
            
            if self.currentRound == 3 {
                self.playerMaxLives = 6
                self.dealerMaxLives = 6
                self.playerLives = min(6, self.playerLives + 1)
                self.dealerLives = min(6, self.dealerLives + 1)
            }
            self.startRound()
        }
    }
    
    private func endGame() {
        phase = .gameOver
        dealerSpeech = playerLives > 0 ? "不可能... 你赢了。" : "游戏结束。"
    }
    
    func log(_ msg: String) {
        log.append(msg)
        if log.count > 60 { log.removeFirst(log.count - 60) }
    }
}

// Game/Scene/GameScene.swift
import SpriteKit
import SwiftUI

class GameScene: SKScene {
    // Core nodes
    private var shotgun: ShotgunNode!
    private var dealer: DealerNode!
    private var shellTrack: ShellTrackNode!
    private var itemBar: ItemBarNode!
    private var hud: HUDNode!
    private var logNode: LogNode!
    private var magnifierOverlay: MagnifierOverlay?
    
    // State
    private var gameState = GameState()
    private var cancellables = Set<AnyCancellable>()
    
    override func didMove(to view: SKView) {
        setupScene()
        bindState()
        gameState.startNewGame()
    }
    
    private func setupScene() {
        backgroundColor = SKColor(hex: 0x0A030A)
        anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scaleMode = .aspectFill
        
        // Ambient glow
        let glow1 = SKSpriteNode(color: SKColor(hex: 0x440044, alpha: 0.08), size: CGSize(width: 400, height: 400))
        glow1.position = CGPoint(x: -150, y: -200)
        glow1.zPosition = -10
        glow1.blendMode = .add
        addChild(glow1)
        glow1.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.12, duration: 3),
            .fadeAlpha(to: 0.05, duration: 3)
        ])))
        
        let glow2 = SKSpriteNode(color: SKColor(hex: 0x002244, alpha: 0.06), size: CGSize(width: 350, height: 350))
        glow2.position = CGPoint(x: 180, y: 220)
        glow2.zPosition = -10
        glow2.blendMode = .add
        addChild(glow2)
        glow2.run(.repeatForever(.sequence([
            .fadeAlpha(to: 0.1, duration: 4),
            .fadeAlpha(to: 0.03, duration: 4)
        ])))
        
        // Shotgun
        shotgun = ShotgunNode()
        shotgun.position = CGPoint(x: 0, y: -60)
        addChild(shotgun)
        
        // Dealer
        dealer = DealerNode()
        dealer.position = CGPoint(x: 0, y: 280)
        addChild(dealer)
        
        // Shell track
        shellTrack = ShellTrackNode()
        shellTrack.position = CGPoint(x: 0, y: 120)
        addChild(shellTrack)
        
        // Item bar
        itemBar = ItemBarNode()
        itemBar.position = CGPoint(x: 0, y: -320)
        addChild(itemBar)
        
        // HUD
        hud = HUDNode()
        hud.position = CGPoint(x: -size.width/2 + 20, y: size.height/2 - 80)
        hud.zPosition = 50
        addChild(hud)
        
        // Log
        logNode = LogNode()
        logNode.position = CGPoint(x: -size.width/2 + 20, y: -size.height/2 + 20)
        logNode.zPosition = 50
        addChild(logNode)
    }
    
    private func bindState() {
        // Phase changes
        gameState.$phase.sink { [weak self] phase in
            self?.onPhaseChange(phase)
        }.store(in: &cancellables)
        
        gameState.$shells.sink { [weak self] shells in
            self?.shellTrack.setShells(shells, currentIndex: self?.gameState.currentShellIndex ?? 0)
        }.store(in: &cancellables)
        
        gameState.$currentShellIndex.sink { [weak self] idx in
            self?.shellTrack.setCurrentIndex(idx)
            self?.shotgun.updateShellDisplay(shells: self?.gameState.shells ?? [], index: idx, known: self?.gameState.knownShell)
        }.store(in: &cancellables)
        
        gameState.$knownShell.sink { [weak self] known in
            self?.shotgun.setKnownShell(known)
        }.store(in: &cancellables)
        
        gameState.$playerItems.sink { [weak self] items in
            self?.itemBar.setItems(items, isPlayer: true)
        }.store(in: &cancellables)
        
        gameState.$dealerItems.sink { [weak self] items in
            self?.itemBar.setItems(items, isPlayer: false)
        }.store(in: &cancellables)
        
        gameState.$playerLives.combineLatest(gameState.$playerMaxLives, gameState.$dealerLives, gameState.$dealerMaxLives)
            .sink { [weak self] pL, pM, dL, dM in
                self?.hud.updateLives(player: (pL, pM), dealer: (dL, dM))
            }.store(in: &cancellables)
        
        gameState.$sawActive.sink { [weak self] active in
            self?.shotgun.setSawActive(active)
        }.store(in: &cancellables)
        
        gameState.$log.sink { [weak self] log in
            self?.logNode.setLog(log)
        }.store(in: &cancellables)
        
        gameState.$dealerMood.sink { [weak self] mood in
            self?.dealer.setMood(mood)
        }.store(in: &cancellables)
        
        gameState.$dealerSpeech.sink { [weak self] speech in
            if let s = speech {
                self?.addChild(self!.dealer.speechBubble(s))
            }
        }.store(in: &cancellables)
        
        gameState.$magnifierShell.sink { [weak self] shell in
            self?.showMagnifier(shell)
        }.store(in: &cancellables)
        
        gameState.$phoneHint.sink { [weak self] hint in
            self?.showPhoneHint(hint)
        }.store(in: &cancellables)
        
        // Notifications
        NotificationCenter.default.publisher(for: .itemTapped).sink { [weak self] notif in
            if let item = notif.object as? Item {
                self?.gameState.useItem(item)
            }
        }.store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .shootSelf).sink { [weak self] _ in
            self?.gameState.fire(atSelf: true)
        }.store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .shootDealer).sink { [weak self] _ in
            self?.gameState.fire(atSelf: false)
        }.store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: .discardItem).sink { [weak self] notif in
            if let item = notif.object as? Item {
                self?.gameState.discardItem(item)
            }
        }.store(in: &cancellables)
    }
    
    private func onPhaseChange(_ phase: GameState.GamePhase) {
        switch phase {
        case .dealing:
            dealer.setMood(.neutral)
            shotgun.prepareDealAnimation(shells: gameState.shells)
        case .playerTurn:
            shotgun.aimAtDealer { }
            itemBar.setEnabled(true)
        case .dealerTurn:
            shotgun.aimAtSelf { }
            itemBar.setEnabled(false)
        case .roundEnd:
            dealer.setMood(.amused)
        case .gameOver:
            showGameOver()
        case .menu:
            break
        }
    }
    
    private func showMagnifier(_ shell: ShellType?) {
        magnifierOverlay?.removeFromParent()
        guard let shell = shell else { return }
        
        let overlay = MagnifierOverlay(shell: shell)
        overlay.zPosition = 100
        overlay.position = .zero
        overlay.alpha = 0
        addChild(overlay)
        overlay.run(.fadeIn(withDuration: 0.2))
        magnifierOverlay = overlay
    }
    
    private func showPhoneHint(_ hint: String?) {
        guard let hint = hint else { return }
        let label = SKLabelNode(text: "📞 \(hint)")
        label.fontName = "Menlo-Bold"
        label.fontSize = 18
        label.fontColor = SKColor(hex: 0x00CCFF)
        label.position = CGPoint(x: 0, y: -260)
        label.zPosition = 60
        label.alpha = 0
        addChild(label)
        label.run(.sequence([
            .group([.fadeIn(withDuration: 0.2), .moveBy(x: 0, y: 20, duration: 0.2)]),
            .wait(forDuration: 3),
            .group([.fadeOut(withDuration: 0.3), .moveBy(x: 0, y: 20, duration: 0.3)]),
            .removeFromParent()
        ]))
    }
    
    private func showGameOver() {
        let won = gameState.playerLives > 0
        let overlay = SKNode()
        overlay.zPosition = 200
        
        let bg = SKShapeNode(rectOf: CGSize(width: size.width, height: size.height), cornerRadius: 0)
        bg.fillColor = SKColor(hex: 0x000000, alpha: 0.9)
        bg.strokeColor = .clear
        overlay.addChild(bg)
        
        let title = SKLabelNode(text: won ? "🏆 胜利" : "☠️ 失败")
        title.fontName = "Menlo-Bold"
        title.fontSize = 48
        title.fontColor = won ? SKColor(hex: 0xFFDD00) : SKColor(hex: 0xFF3333)
        title.position = CGPoint(x: 0, y: 60)
        overlay.addChild(title)
        
        let stats = SKLabelNode(text: "你的血量：\(gameState.playerLives)/\(gameState.playerMaxLives)   恶魔血量：\(gameState.dealerLives)/\(gameState.dealerMaxLives)   回合：\(min(gameState.currentRound, 3))/3")
        stats.fontName = "Menlo"
        stats.fontSize = 16
        stats.fontColor = .white
        stats.position = CGPoint(x: 0, y: 0)
        overlay.addChild(stats)
        
        let restart = SKLabelNode(text: "点击屏幕重新开始")
        restart.fontName = "Menlo"
        restart.fontSize = 18
        restart.fontColor = SKColor(white: 0.7, alpha: 1)
        restart.position = CGPoint(x: 0, y: -80)
        overlay.addChild(restart)
        
        let pulse = SKAction.sequence([
            .fadeAlpha(to: 0.4, duration: 1),
            .fadeAlpha(to: 1, duration: 1)
        ])
        restart.run(.repeatForever(pulse))
        
        overlay.alpha = 0
        addChild(overlay)
        overlay.run(.fadeIn(withDuration: 0.5))
        
        // Tap to restart
        overlay.isUserInteractionEnabled = true
        let tapHandler = SKAction.run { [weak self] in
            self?.restartGame()
        }
        // Use a simple touch handler
        self.view?.scene?.isUserInteractionEnabled = true
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState.phase == .gameOver {
            restartGame()
            return
        }
        
        if gameState.phase == .menu {
            gameState.startNewGame()
            return
        }
        
        // Dismiss magnifier
        if let overlay = magnifierOverlay {
            let loc = touches.first?.location(in: self) ?? .zero
            if !overlay.contains(loc) {
                overlay.run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
                magnifierOverlay = nil
                gameState.magnifierShell = nil
            }
        }
    }
    
    private func restartGame() {
        removeAllChildren()
        cancellables.removeAll()
        didMove(to: view!)
    }
}

extension Notification.Name {
    static let shootSelf = Notification.Name("shootSelf")
    static let shootDealer = Notification.Name("shootDealer")
    static let discardItem = Notification.Name("discardItem")
}

// Game/UI/ShellTrackNode.swift
import SpriteKit

class ShellTrackNode: SKNode {
    private var shellNodes: [ShellNode] = []
    private var indexMarker: SKShapeNode!
    
    override init() {
        super.init()
        zPosition = 30
        
        indexMarker = SKShapeNode(rectOf: CGSize(width: 22, height: 38), cornerRadius: 4)
        indexMarker.strokeColor = SKColor(hex: 0xFFDD00)
        indexMarker.lineWidth = 3
        indexMarker.fillColor = .clear
        indexMarker.zPosition = 5
        indexMarker.alpha = 0
        addChild(indexMarker)
        
        let pulse = SKAction.sequence([
            .fadeAlpha(to: 1, duration: 0.5),
            .fadeAlpha(to: 0.4, duration: 0.5)
        ])
        indexMarker.run(.repeatForever(pulse))
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setShells(_ shells: [ShellType], currentIndex: Int) {
        shellNodes.forEach { $0.removeFromParent() }
        shellNodes = []
        
        let spacing: CGFloat = 22
        let startX = -CGFloat(shells.count - 1) * spacing / 2
        
        for (i, shell) in shells.enumerated() {
            let node = ShellNode(type: shell)
            node.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            node.zPosition = i < currentIndex ? 1 : (i == currentIndex ? 3 : 2)
            addChild(node)
            shellNodes.append(node)
            
            // Spent shells fade
            if i < currentIndex {
                node.run(.fadeAlpha(to: 0.3, duration: 0.3))
                node.run(.scale(to: 0.85, duration: 0.3))
            }
        }
        
        setCurrentIndex(currentIndex)
    }
    
    func setCurrentIndex(_ idx: Int) {
        for (i, node) in shellNodes.enumerated() {
            let isCurrent = i == idx
            let isPast = i < idx
            node.zPosition = isCurrent ? 3 : (isPast ? 1 : 2)
            
            if isPast {
                node.run(.group([
                    .fadeAlpha(to: 0.3, duration: 0.2),
                    .scale(to: 0.85, duration: 0.2)
                ]))
            } else if isCurrent {
                node.run(.group([
                    .fadeAlpha(to: 1, duration: 0.2),
                    .scale(to: 1, duration: 0.2)
                ]))
                indexMarker.position = node.position
                indexMarker.alpha = 1
            } else {
                node.run(.group([
                    .fadeAlpha(to: 1, duration: 0.2),
                    .scale(to: 1, duration: 0.2)
                ]))
            }
        }
        
        if idx >= shellNodes.count {
            indexMarker.alpha = 0
        }
    }
}

// Game/UI/ItemBarNode.swift
import SpriteKit

class ItemBarNode: SKNode {
    private var playerContainer = SKNode()
    private var dealerContainer = SKNode()
    private var enabled = true
    
    override init() {
        super.init()
        zPosition = 40
        
        addChild(dealerContainer)
        addChild(playerContainer)
        
        dealerContainer.position = CGPoint(x: 0, y: 60)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setItems(_ items: [Item], isPlayer: Bool) {
        let container = isPlayer ? playerContainer : dealerContainer
        container.removeAllChildren()
        
        let spacing: CGFloat = 78
        let startX = -CGFloat(items.count - 1) * spacing / 2
        
        for (i, item) in items.enumerated() {
            let node = ItemNode(item: item)
            node.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            container.addChild(node)
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        self.enabled = enabled
        playerContainer.isUserInteractionEnabled = enabled
        playerContainer.alpha = enabled ? 1 : 0.5
    }
}

// Game/UI/HUDNode.swift
import SpriteKit

class HUDNode: SKNode {
    private var playerLives: [SKShapeNode] = []
    private var dealerLives: [SKShapeNode] = []
    private var roundLabel: SKLabelNode!
    
    override init() {
        super.init()
        
        // Round indicator
        roundLabel = SKLabelNode(text: "ROUND 1/3")
        roundLabel.fontName = "Menlo-Bold"
        roundLabel.fontSize = 14
        label.fontColor = SKColor(hex: 0xFFDD00)
        roundLabel.position = CGPoint(x: 0, y: 80)
        addChild(roundLabel)
        
        // Dealer lives (top)
        let dealerContainer = SKNode()
        dealerContainer.position = CGPoint(x: 0, y: 40)
        addChild(dealerContainer)
        
        for i in 0..<6 {
            let heart = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 4))
            path.addCurve(to: CGPoint(x: -8, y: -4), control1: CGPoint(x: 0, y: 0), control2: CGPoint(x: -4, y: -8))
            path.addCurve(to: CGPoint(x: 8, y: -4), control1: CGPoint(x: -4, y: -10), control2: CGPoint(x: 4, y: -8))
            path.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: 4, y: -8), control2: CGPoint(x: 0, y: 0))
            heart.path = path
            heart.fillColor = SKColor(hex: 0xFF2244)
            heart.strokeColor = SKColor(hex: 0x880022)
            heart.lineWidth = 1
            heart.position = CGPoint(x: CGFloat(i - 2.5) * 18, y: 0)
            heart.zPosition = 1
            dealerContainer.addChild(heart)
            dealerLives.append(heart)
        }
        
        let dealerLabel = SKLabelNode(text: "DEALER")
        dealerLabel.fontName = "Menlo"
        dealerLabel.fontSize = 10
        dealerLabel.fontColor = SKColor(hex: 0xAA44AA)
        dealerLabel.position = CGPoint(x: 0, y: -22)
        dealerContainer.addChild(dealerLabel)
        
        // Player lives (bottom)
        let playerContainer = SKNode()
        playerContainer.position = CGPoint(x: 0, y: -40)
        addChild(playerContainer)
        
        for i in 0..<6 {
            let heart = SKShapeNode()
            let path = CGMutablePath()
            path.move(to: CGPoint(x: 0, y: 4))
            path.addCurve(to: CGPoint(x: -8, y: -4), control1: CGPoint(x: 0, y: 0), control2: CGPoint(x: -4, y: -8))
            path.addCurve(to: CGPoint(x: 8, y: -4), control1: CGPoint(x: -4, y: -10), control2: CGPoint(x: 4, y: -8))
            path.addCurve(to: CGPoint(x: 0, y: 4), control1: CGPoint(x: 4, y: -8), control2: CGPoint(x: 0, y: 0))
            heart.path = path
            heart.fillColor = SKColor(hex: 0x44FF88)
            heart.strokeColor = SKColor(hex: 0x228844)
            heart.lineWidth = 1
            heart.position = CGPoint(x: CGFloat(i - 2.5) * 18, y: 0)
            heart.zPosition = 1
            playerContainer.addChild(heart)
            playerLives.append(heart)
        }
        
        let playerLabel = SKLabelNode(text: "YOU")
        playerLabel.fontName = "Menlo"
        playerLabel.fontSize = 10
        playerLabel.fontColor = SKColor(hex: 0x44FF88)
        playerLabel.position = CGPoint(x: 0, y: -22)
        playerContainer.addChild(playerLabel)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func updateLives(player: (Int, Int), dealer: (Int, Int)) {
        for (i, heart) in playerLives.enumerated() {
            heart.alpha = i < player.0 ? 1.0 : 0.15
            heart.run(.scale(to: i < player.0 ? 1.0 : 0.6, duration: 0.2))
        }
        for (i, heart) in dealerLives.enumerated() {
            heart.alpha = i < dealer.0 ? 1.0 : 0.15
            heart.run(.scale(to: i < dealer.0 ? 1.0 : 0.6, duration: 0.2))
        }
    }
}

// Game/UI/LogNode.swift
import SpriteKit

class LogNode: SKNode {
    private var labels: [SKLabelNode] = []
    private let maxLines = 8
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setLog(_ log: [String]) {
        let recent = Array(log.suffix(maxLines))
        
        // Update existing or create new
        for (i, msg) in recent.enumerated() {
            if i < labels.count {
                labels[i].text = "> \(msg)"
            } else {
                let label = SKLabelNode(text: "> \(msg)")
                label.fontName = "Menlo"
                label.fontSize = 11
                label.fontColor = SKColor(white: 0.7, alpha: 1)
                label.horizontalAlignmentMode = .left
                label.verticalAlignmentMode = .bottom
                label.position = CGPoint(x: 0, y: CGFloat(i) * 18)
                addChild(label)
                labels.append(label)
            }
        }
        
        // Remove excess
        while labels.count > recent.count {
            labels.last?.removeFromParent()
            labels.removeLast()
        }
        
        // Color code
        for label in labels {
            let text = label.text ?? ""
            if text.contains("实弹") || text.contains("扣") || text.contains("☠️") || text.contains("💥") {
                label.fontColor = SKColor(hex: 0xFF4444)
            } else if text.contains("空包") || text.contains("安全") || text.contains("🏆") || text.contains("💨") {
                label.fontColor = SKColor(hex: 0x44FF88)
            } else if text.contains("道具") || text.contains("获得") || text.contains("🔍") || text.contains("🍺") || text.contains("🔗") || text.contains("🪚") || text.contains("💊") || text.contains("🔄") || text.contains("📞") || text.contains("💉") {
                label.fontColor = SKColor(hex: 0xFFDD00)
            } else {
                label.fontColor = SKColor(white: 0.7, alpha: 1)
            }
        }
    }
}

// Game/UI/MagnifierOverlay.swift
import SpriteKit

class MagnifierOverlay: SKNode {
    init(shell: ShellType) {
        super.init()
        
        let panel = SKShapeNode(rectOf: CGSize(width: 280, height: 180), cornerRadius: 16)
        panel.fillColor = SKColor(hex: 0x0A000A, alpha: 0.98)
        panel.strokeColor = SKColor(hex: shell == .live ? 0xFF2222 : 0xDDDD33)
        panel.lineWidth = 3
        panel.glowWidth = shell == .live ? 8 : 6
        addChild(panel)
        
        let icon = SKLabelNode(text: shell == .live ? "🔴" : "⚪")
        icon.fontSize = 72
        icon.position = CGPoint(x: 0, y: 20)
        panel.addChild(icon)
        
        let label = SKLabelNode(text: shell == .live ? "实弹" : "空包弹")
        label.fontName = "Menlo-Bold"
        label.fontSize = 28
        label.fontColor = SKColor(hex: shell == .live ? 0xFF4444 : 0xDDDD33)
        label.position = CGPoint(x: 0, y: -30)
        panel.addChild(label)
        
        let detail = SKLabelNode(text: shell == .live ? "击中将扣除 1~2 点血量" : "击中安全 · 获得额外回合")
        detail.fontName = "Menlo"
        detail.fontSize = 13
        detail.fontColor = SKColor(white: 0.7, alpha: 1)
        detail.position = CGPoint(x: 0, y: -70)
        panel.addChild(detail)
        
        let tap = SKLabelNode(text: "点击空白处关闭")
        tap.fontName = "Menlo"
        tap.fontSize = 11
        tap.fontColor = SKColor(white: 0.5, alpha: 1)
        tap.position = CGPoint(x: 0, y: -110)
        panel.addChild(tap)
        
        setScale(0.8)
        run(.scale(to: 1.0, duration: 0.2))
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

// Game/Scene/GameViewController.swift
import UIKit
import SpriteKit
import SwiftUI

class GameViewController: UIViewController {
    private var skView: SKView!
    private var gameScene: GameScene!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupSKView()
        presentScene()
    }
    
    private func setupSKView() {
        skView = SKView(frame: view.bounds)
        skView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        skView.ignoresSiblingOrder = true
        skView.preferredFramesPerSecond = 60
        skView.showsFPS = false
        skView.showsNodeCount = false
        skView.showsPhysics = false
        view.addSubview(skView)
    }
    
    private func presentScene() {
        let scene = GameScene(size: view.bounds.size)
        scene.scaleMode = .aspectFill
        gameScene = scene
        skView.presentScene(scene)
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    override var prefersStatusBarHidden: Bool { true }
    override var prefersHomeIndicatorAutoHidden: Bool { true }
}

// SwiftUI wrapper for App entry
struct GameView: UIViewControllerRepresentable {
    func makeUIViewController(context: Context) -> GameViewController {
        GameViewController()
    }
    
    func updateUIViewController(_ uiViewController: GameViewController, context: Context) {}
}

#Preview {
    GameView()
        .ignoresSafeArea()
}