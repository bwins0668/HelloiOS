// Game/Data/GameData.swift
import Foundation
import Combine

// MARK: - Shell

enum ShellType: Equatable, CaseIterable {
    case live
    case blank
    
    var displayName: String {
        switch self {
        case .live: return "实弹"
        case .blank: return "空包"
        }
    }
    
    var isLive: Bool { self == .live }
    var color: UInt32 { isLive ? 0xFF2222 : 0xDDDD33 }
}

// MARK: - Round Config

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

// MARK: - Items

enum ItemType: String, CaseIterable, Identifiable, Equatable {
    case magnifier = "magnifier"
    case beer = "beer"
    case handcuffs = "handcuffs"
    case saw = "saw"
    case medicine = "medicine"
    case inverter = "inverter"
    case cigarettes = "cigarettes"
    case adrenaline = "adrenaline"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .magnifier: return "放大镜"
        case .beer: return "啤酒"
        case .handcuffs: return "手铐"
        case .saw: return "手锯"
        case .medicine: return "药品"
        case .inverter: return "逆变器"
        case .cigarettes: return "香烟"
        case .adrenaline: return "肾上腺素"
        }
    }
    
    var iconName: String {
        switch self {
        case .magnifier: return "🔍"
        case .beer: return "🍺"
        case .handcuffs: return "🔗"
        case .saw: return "🪚"
        case .medicine: return "💊"
        case .inverter: return "🔄"
        case .cigarettes: return "🚬"
        case .adrenaline: return "💉"
        }
    }
    
    var color: UInt32 {
        switch self {
        case .magnifier: return 0x00FFFF
        case .beer: return 0xFFB800
        case .handcuffs: return 0xAA00FF
        case .saw: return 0xFF3333
        case .medicine: return 0x00FF66
        case .inverter: return 0xFF00AA
        case .cigarettes: return 0xCCCCCC
        case .adrenaline: return 0xFF0044
        }
    }
    
    var description: String {
        switch self {
        case .magnifier: return "查看当前弹膛类型"
        case .beer: return "退出当前弹壳（随机）"
        case .handcuffs: return "对方跳过下一回合"
        case .saw: return "本次射击伤害翻倍"
        case .medicine: return "50%治疗1命 / 50%扣1命"
        case .inverter: return "翻转当前弹膛类型"
        case .cigarettes: return "恢复 1 命"
        case .adrenaline: return "偷取对方 1 个道具并使用"
        }
    }
    
    var spawnWeight: Int {
        switch self {
        case .magnifier: return 10
        case .beer: return 12
        case .handcuffs: return 8
        case .saw: return 8
        case .medicine: return 10
        case .inverter: return 6
        case .cigarettes: return 6
        case .adrenaline: return 4
        }
    }
}

struct Item: Identifiable, Equatable {
    let id: UUID
    let type: ItemType
    var used: Bool = false
    
    init(type: ItemType) {
        self.id = UUID()
        self.type = type
    }
    
    static func randomSet(count: Int) -> [Item] {
        var pool: [ItemType] = []
        for type in ItemType.allCases {
            pool += Array(repeating: type, count: type.spawnWeight)
        }
        pool.shuffle()
        return (0..<count).map { Item(type: pool[$0]) }
    }
}

// MARK: - Dealer Lines

struct DealerLines {
    static let intro = [
        "欢迎来到地狱的赌桌。",
        "规则很简单，活下来就行。",
        "拿好你的霰弹枪。"
    ]
    
    static let roundStart = [
        "第 %d 轮。",
        "新的一局。",
        "继续。"
    ]
    
    static let playerTurn = [
        "你的回合。",
        "轮到你了。",
        "做个选择。"
    ]
    
    static let dealerTurn = [
        "我的回合。",
        "轮到我了。",
        "让我想想。"
    ]
    
    static let liveShell = [
        "砰！实弹。",
        "真可惜。",
        "运气不好。"
    ]
    
    static let blankShell = [
        "空包弹。",
        "呼...运气好。",
        "下一发。"
    ]
    
    static let playerDeath = [
        "游戏结束。",
        "下地狱去吧。",
        "太弱了。"
    ]
    
    static let dealerDeath = [
        "不可能...",
        "你赢了...这一局。",
        "下次见。"
    ]
    
    static let itemUsed = [
        "有意思的玩意儿。",
        "道具...",
        "聪明。"
    ]
    
    static func random<T>(_ arr: [T]) -> T { arr.randomElement()! }
}

// MARK: - Game State

@MainActor
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
    @Published var dealerMood: DealerMood = .neutral
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
            if currentShellIndex < shells.count {
                shells[currentShellIndex] = shells[currentShellIndex] == .live ? .blank : .live
                knownShell = nil
                log("🔄 逆变器：翻转当前弹膛")
            }
            
        case .cigarettes:
            if currentShellIndex + 1 < shells.count {
                let hint = shells[currentShellIndex + 1]
                phoneHint = "下一发是 \(hint.displayName)"
                log("📞 电话：\(phoneHint!)")
            }
            
        case .adrenaline:
            let available = dealerItems.enumerated().filter { !$0.element.used }.map { $0.offset }
            if let idx = available.randomElement() {
                var stolen = dealerItems[idx]
                stolen.used = true
                playerItems.append(stolen)
                log("💉 肾上腺素：偷走恶魔的 \(stolen.type.displayName)")
            } else {
                log("💉 肾上腺素：恶魔没有可偷的道具")
            }
        }
        
        playerItems[idx].used = true
        
        if ![.magnifier, .cigarettes].contains(item.type) {
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
                return
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
        
        let availableItems = dealerItems.enumerated().filter { !$0.element.used }.map { $0.offset }
        if !availableItems.isEmpty && Double.random(in: 0...1) < 0.2 {
            useDealerItem(availableItems.randomElement()!)
            return
        }
        
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
        case .saw:
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
        case .cigarettes:
            break
        case .adrenaline:
            let available = playerItems.enumerated().filter { !$0.element.used }.map { $0.offset }
            if let pIdx = available.randomElement() {
                var stolen = playerItems[pIdx]
                stolen.used = true
                dealerItems.append(stolen)
                log("💉 恶魔用肾上腺素：偷走你的 \(stolen.type.displayName)")
            }
        }
        
        dealerItems[idx].used = true
        endPlayerTurn()
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

// MARK: - Dealer Mood

enum DealerMood { case neutral, thinking, amused, annoyed, surprised, dead }