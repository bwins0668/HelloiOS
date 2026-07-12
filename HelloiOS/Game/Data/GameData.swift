// Game/Data/RoundConfig.swift
import Foundation

enum ShellType: Equatable, CaseIterable {
    case live
    case blank
    
    var displayName: String {
        switch self {
        case .live: return "实弹"
        case .blank: return "空包"
        }
    }
}

struct RoundConfig {
    let round: Int
    let liveCount: Int
    let blankCount: Int
    let maxLives: Int
    let startingLives: Int
    let playerItemSlots: Int
    let dealerItemSlots: Int
    
    static let all: [RoundConfig] = [
        RoundConfig(round: 1, liveCount: 2, blankCount: 2, maxLives: 2, startingLives: 2, playerItemSlots: 2, dealerItemSlots: 2),
        RoundConfig(round: 2, liveCount: 3, blankCount: 2, maxLives: 4, startingLives: 4, playerItemSlots: 3, dealerItemSlots: 3),
        RoundConfig(round: 3, liveCount: 4, blankCount: 3, maxLives: 6, startingLives: 6, playerItemSlots: 4, dealerItemSlots: 4)
    ]
    
    var totalShells: Int { liveCount + blankCount }
    
    func generateShells() -> [ShellType] {
        var shells = Array(repeating: ShellType.live, count: liveCount) +
                     Array(repeating: ShellType.blank, count: blankCount)
        shells.shuffle()
        return shells
    }
}

// Game/Data/ItemDatabase.swift
import Foundation

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
        case .magnifier: return "magnifyingglass"
        case .beer: return "mug.fill"
        case .handcuffs: return "handcuffs"
        case .saw: return "scissors"
        case .medicine: return "pills.fill"
        case .inverter: return "arrow.triangle.2.circlepath"
        case .cigarettes: return "smoke.fill"
        case .adrenaline: return "bolt.heart.fill"
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
    
    var isConsumable: Bool { true }
    var canUseOnSelf: Bool { true }
    var canUseOnOpponent: Bool {
        switch self {
        case .handcuffs, .adrenaline: return true
        default: return false
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
}

// Game/Data/DealerLines.swift
import Foundation

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