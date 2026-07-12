// Game/Entities/GameUI.swift
import SpriteKit

// MARK: - Shell Track Node
class ShellTrackNode: SKNode {
    private var shellNodes: [ShellDisplayNode] = []
    
    func setShells(_ shells: [ShellType], currentIndex: Int) {
        shellNodes.forEach { $0.removeFromParent() }
        shellNodes.removeAll()
        
        let spacing: CGFloat = 36
        let totalWidth = CGFloat(max(shells.count - 1, 0)) * spacing
        let startX = -totalWidth / 2
        
        for (i, shell) in shells.enumerated() {
            let node = ShellDisplayNode(type: shell, index: i)
            node.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            node.zPosition = 30
            addChild(node)
            shellNodes.append(node)
        }
        
        setCurrentIndex(currentIndex)
    }
    
    func setCurrentIndex(_ index: Int) {
        for (i, node) in shellNodes.enumerated() {
            let isCurrent = i == index
            let isPast = i < index
            node.setState(isCurrent: isCurrent, isPast: isPast, known: nil)
        }
    }
}

// MARK: - Item Bar Node
class ItemBarNode: SKNode {
    private var playerItemsNode = SKNode()
    private var dealerItemsNode = SKNode()
    
    override init() {
        super.init()
        addChild(dealerItemsNode)
        addChild(playerItemsNode)
        dealerItemsNode.position = CGPoint(x: 0, y: 60)
        zPosition = 40
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setItems(_ items: [Item], isPlayer: Bool) {
        let container = isPlayer ? playerItemsNode : dealerItemsNode
        container.removeAllChildren()
        
        let spacing: CGFloat = 78
        let totalWidth = CGFloat(max(items.count - 1, 0)) * spacing
        let startX = -totalWidth / 2
        
        for (i, item) in items.enumerated() {
            let node = ItemDisplayNode(item: item, isPlayer: isPlayer)
            node.position = CGPoint(x: startX + CGFloat(i) * spacing, y: 0)
            container.addChild(node)
        }
    }
    
    func setEnabled(_ enabled: Bool) {
        playerItemsNode.children.forEach { node in
            if let itemNode = node as? ItemDisplayNode {
                itemNode.isUserInteractionEnabled = enabled
                node.alpha = enabled ? 1 : 0.5
            }
        }
    }
}

// MARK: - HUD Node
class HUDNode: SKNode {
    private let dealerLivesNode = SKNode()
    private let playerLivesNode = SKNode()
    private let roundLabel = SKLabelNode()
    private let shellsLabel = SKLabelNode()
    private let turnLabel = SKLabelNode()
    private let sawIndicator = SKLabelNode()
    
    override init() {
        super.init()
        zPosition = 50
        
        // Dealer lives (top)
        dealerLivesNode.position = CGPoint(x: 0, y: 40)
        addChild(dealerLivesNode)
        
        let dealerTitle = SKLabelNode(text: "DEALER")
        dealerTitle.fontName = "Menlo"
        dealerTitle.fontSize = 10
        dealerTitle.fontColor = SKColor(hex: 0xAA44AA)
        dealerTitle.position = CGPoint(x: 0, y: -22)
        dealerLivesNode.addChild(dealerTitle)
        
        // Round info
        roundLabel.fontName = "Menlo-Bold"
        roundLabel.fontSize = 12
        roundLabel.fontColor = SKColor(hex: 0xFFB800)
        roundLabel.position = CGPoint(x: -150, y: 10)
        addChild(roundLabel)
        
        shellsLabel.fontName = "Menlo"
        shellsLabel.fontSize = 11
        shellsLabel.fontColor = SKColor(white: 0.6, alpha: 1)
        shellsLabel.position = CGPoint(x: 150, y: 10)
        shellsLabel.horizontalAlignmentMode = .right
        addChild(shellsLabel)
        
        // Turn indicator
        turnLabel.fontName = "Menlo-Bold"
        turnLabel.fontSize = 14
        turnLabel.fontColor = SKColor(hex: 0x00CCFF)
        turnLabel.position = CGPoint(x: 0, y: -20)
        addChild(turnLabel)
        
        // Player lives (bottom)
        playerLivesNode.position = CGPoint(x: 0, y: -50)
        addChild(playerLivesNode)
        
        let playerTitle = SKLabelNode(text: "YOU")
        playerTitle.fontName = "Menlo"
        playerTitle.fontSize = 10
        playerTitle.fontColor = SKColor(hex: 0x00FF88)
        playerTitle.position = CGPoint(x: 0, y: -22)
        playerLivesNode.addChild(playerTitle)
        
        // Saw indicator
        sawIndicator.fontName = "Menlo-Bold"
        sawIndicator.fontSize = 12
        sawIndicator.fontColor = SKColor(hex: 0xFF2244)
        sawIndicator.position = CGPoint(x: 0, y: -80)
        sawIndicator.alpha = 0
        addChild(sawIndicator)
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func updateLives(player: (Int, Int), dealer: (Int, Int)) {
        // Dealer
        dealerLivesNode.children.filter { $0 is HeartNode }.forEach { $0.removeFromParent() }
        let dSpacing: CGFloat = 30
        let dStartX = -CGFloat(dealer.1 - 1) * dSpacing / 2
        for i in 0..<dealer.1 {
            let heart = HeartNode(filled: i < dealer.0, color: 0xFF2244)
            heart.position = CGPoint(x: dStartX + CGFloat(i) * dSpacing, y: 22)
            dealerLivesNode.addChild(heart)
        }
        
        // Player
        playerLivesNode.children.filter { $0 is HeartNode }.forEach { $0.removeFromParent() }
        let pSpacing: CGFloat = 30
        let pStartX = -CGFloat(player.1 - 1) * pSpacing / 2
        for i in 0..<player.1 {
            let heart = HeartNode(filled: i < player.0, color: 0x00FF88)
            heart.position = CGPoint(x: pStartX + CGFloat(i) * pSpacing, y: -22)
            playerLivesNode.addChild(heart)
        }
    }
    
    func setRound(_ round: Int, total: Int = 3) { roundLabel.text = "回合 \(round)/\(total)" }
    func setShellsRemaining(_ count: Int) { shellsLabel.text = "剩余 \(count) 发" }
    func setTurn(_ turn: GameState.Turn) {
        let text = turn == .player ? "▶ 你的回合" : "▶ 恶魔回合"
        let color = turn == .player ? SKColor(hex: 0x00FF88) : SKColor(hex: 0xFF2244)
        turnLabel.text = text
        turnLabel.fontColor = color
        turnLabel.run(SKAction.sequence([SKAction.scale(to: 1.2, duration: 0.1), SKAction.scale(to: 1.0, duration: 0.1)]))
    }
    func setSawActive(_ active: Bool) {
        sawIndicator.text = active ? "🪚 手锯生效 · 伤害×2" : ""
        sawIndicator.run(SKAction.sequence([
            SKAction.fadeAlpha(to: active ? 1 : 0, duration: 0.2),
            SKAction.scale(to: active ? 1.1 : 1.0, duration: 0.2)
        ]))
    }
}

// MARK: - Heart Node
class HeartNode: SKNode {
    init(filled: Bool, color: UInt32) {
        super.init()
        
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: -6))
        path.addCurve(to: CGPoint(x: -10, y: 0), control1: CGPoint(x: 0, y: 2), control2: CGPoint(x: -10, y: -6))
        path.addCurve(to: CGPoint(x: 0, y: 10), control1: CGPoint(x: -10, y: 6), control2: CGPoint(x: 0, y: 6))
        path.addCurve(to: CGPoint(x: 10, y: 0), control1: CGPoint(x: 0, y: 6), control2: CGPoint(x: 10, y: 6))
        path.addCurve(to: CGPoint(x: 0, y: -6), control1: CGPoint(x: 10, y: -6), control2: CGPoint(x: 0, y: 2))
        path.closeSubpath()
        
        let shape = SKShapeNode(path: path)
        shape.fillColor = filled ? SKColor(hex: color) : SKColor(white: 0.1, alpha: 1)
        shape.strokeColor = SKColor(hex: color, alpha: 0.5)
        shape.lineWidth = 1.5
        addChild(shape)
        
        if filled {
            let glow = shape.copy() as! SKShapeNode
            glow.fillColor = SKColor(hex: color).withAlphaComponent(0.3)
            glow.strokeColor = .clear
            glow.lineWidth = 0
            glow.zPosition = -1
            glow.run(SKAction.repeatForever(SKAction.sequence([
                SKAction.scale(to: 1.2, duration: 0.8),
                SKAction.scale(to: 1.0, duration: 0.8)
            ])))
            addChild(glow)
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Log Node
class LogNode: SKNode {
    private var logLabels: [SKLabelNode] = []
    private let maxLines = 12
    
    override init() { super.init() }
    required init?(coder: NSCoder) { fatalError() }
    
    func setLog(_ messages: [String]) {
        while logLabels.count > maxLines {
            logLabels.removeFirst().removeFromParent()
        }
        
        let recent = messages.suffix(maxLines)
        let startY = -CGFloat(recent.count - 1) * 18
        
        for (i, msg) in recent.enumerated() {
            let label: SKLabelNode
            if i < logLabels.count {
                label = logLabels[i]
            } else {
                label = SKLabelNode()
                label.fontName = "Menlo"
                label.fontSize = 10
                label.horizontalAlignmentMode = .left
                label.verticalAlignmentMode = .center
                label.position = CGPoint(x: -200, y: startY + CGFloat(i) * 18)
                label.zPosition = 1
                addChild(label)
                logLabels.append(label)
            }
            
            if msg.contains("💥") || msg.contains("☠️") || msg.contains("扣") {
                label.fontColor = SKColor(hex: 0xFF4444)
            } else if msg.contains("💨") || msg.contains("安全") || msg.contains("🏆") {
                label.fontColor = SKColor(hex: 0x00FF88)
            } else if msg.contains("🔍") || msg.contains("🍺") || msg.contains("🔗") || msg.contains("🪚") || msg.contains("💊") || msg.contains("🔄") || msg.contains("📞") || msg.contains("💉") {
                label.fontColor = SKColor(hex: 0xFFB800)
            } else if msg.contains("🤖") || msg.contains("恶魔") {
                label.fontColor = SKColor(hex: 0xAA44FF)
            } else {
                label.fontColor = SKColor(white: 0.7, alpha: 1)
            }
            
            label.text = msg
            label.position = CGPoint(x: -200, y: startY + CGFloat(i) * 18)
        }
        
        while logLabels.count > recent.count {
            logLabels.removeLast().removeFromParent()
        }
    }
}

// MARK: - Magnifier Overlay
class MagnifierOverlay: SKNode {
    init(shell: ShellType) {
        super.init()
        
        let bg = SKShapeNode(rectOf: CGSize(width: 300, height: 200), cornerRadius: 16)
        bg.fillColor = SKColor(hex: 0x0A000A, alpha: 0.95)
        bg.strokeColor = SKColor(hex: shell == .live ? 0xFF2222 : 0xDDDD33)
        bg.lineWidth = 3
        addChild(bg)
        
        let title = SKLabelNode(text: shell == .live ? "🔴 实弹" : "⚪ 空包弹")
        title.fontName = "Menlo-Bold"
        title.fontSize = 36
        title.fontColor = shell == .live ? SKColor(hex: 0xFF2222) : SKColor(hex: 0xDDDD33)
        title.position = CGPoint(x: 0, y: 30)
        addChild(title)
        
        let desc = SKLabelNode(text: shell == .live ? "击中将造成伤害" : "安全 · 获得额外回合")
        desc.fontName = "Menlo"
        desc.fontSize = 14
        desc.fontColor = SKColor(white: 0.7, alpha: 1)
        desc.position = CGPoint(x: 0, y: -20)
        addChild(desc)
        
        let closeBtn = SKShapeNode(rectOf: CGSize(width: 120, height: 40), cornerRadius: 10)
        closeBtn.fillColor = SKColor(white: 0.15, alpha: 1)
        closeBtn.strokeColor = SKColor(white: 0.3, alpha: 1)
        closeBtn.lineWidth = 1
        closeBtn.position = CGPoint(x: 0, y: -70)
        closeBtn.name = "close"
        addChild(closeBtn)
        
        let closeLabel = SKLabelNode(text: "知道了")
        closeLabel.fontName = "Menlo-Bold"
        closeLabel.fontSize = 14
        closeLabel.fontColor = SKColor(white: 0.9, alpha: 1)
        closeLabel.verticalAlignmentMode = .center
        closeBtn.addChild(closeLabel)
        
        isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: self)
        if atPoint(location).name == "close" {
            run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
        }
    }
}

// MARK: - Game Over Touch Handler
class GameOverTouchHandler: NSObject {
    let overlay: SKNode
    let scene: GameScene
    let won: Bool
    
    init(overlay: SKNode, scene: GameScene, won: Bool) {
        self.overlay = overlay
        self.scene = scene
        self.won = won
        super.init()
        overlay.isUserInteractionEnabled = true
    }
    
    func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: overlay)
        let node = overlay.atPoint(location)
        
        if node.name == "retry" {
            overlay.run(.fadeOut(withDuration: 0.2)) {
                self.scene.handleRetry()
            }
        } else if node.name == "menu" {
            overlay.run(.fadeOut(withDuration: 0.2)) {
                self.scene.handleMenu()
            }
        }
    }
}