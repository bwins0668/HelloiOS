// Game/Scene/GameScene.swift
import SpriteKit
import Combine

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
        
        gameState.$currentTurn.sink { [weak self] turn in
            self?.hud.setTurn(turn)
        }.store(in: &cancellables)
        
        gameState.$currentRound.sink { [weak self] round in
            self?.hud.setRound(round)
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
        
        let bg = SKShapeNode(rectOf: CGSize(width: 360, height: 420), cornerRadius: 24)
        bg.fillColor = SKColor(hex: 0x0A030A, alpha: 0.95)
        bg.strokeColor = won ? SKColor(hex: 0x00FF88) : SKColor(hex: 0xFF2244)
        bg.lineWidth = 3
        overlay.addChild(bg)
        
        let title = SKLabelNode(text: won ? "🏆 你赢了" : "☠️ 你输了")
        title.fontName = "Menlo-Bold"
        title.fontSize = 36
        title.fontColor = won ? SKColor(hex: 0x00FF88) : SKColor(hex: 0xFF2244)
        title.position = CGPoint(x: 0, y: 120)
        title.zPosition = 1
        overlay.addChild(title)
        
        let stats = SKLabelNode(text: "回合: \(min(gameState.currentRound, 3))/3\n你: \(max(0, gameState.playerLives))/\(gameState.playerMaxLives)  恶魔: \(max(0, gameState.dealerLives))/\(gameState.dealerMaxLives)")
        stats.fontName = "Menlo"
        stats.fontSize = 16
        stats.fontColor = SKColor(white: 0.8, alpha: 1)
        stats.numberOfLines = 0
        stats.position = CGPoint(x: 0, y: 30)
        overlay.addChild(stats)
        
        let retryBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 50), cornerRadius: 12)
        retryBtn.fillColor = won ? SKColor(hex: 0x00FF88) : SKColor(hex: 0xFF2244)
        retryBtn.strokeColor = .clear
        retryBtn.position = CGPoint(x: 0, y: -60)
        retryBtn.name = "retry"
        overlay.addChild(retryBtn)
        
        let retryLabel = SKLabelNode(text: won ? "再战一次" : "复仇")
        retryLabel.fontName = "Menlo-Bold"
        retryLabel.fontSize = 20
        retryLabel.fontColor = .black
        retryLabel.verticalAlignmentMode = .center
        retryBtn.addChild(retryLabel)
        
        let menuBtn = SKShapeNode(rectOf: CGSize(width: 200, height: 40), cornerRadius: 10)
        menuBtn.fillColor = SKColor(white: 0.15, alpha: 1)
        menuBtn.strokeColor = SKColor(white: 0.3, alpha: 1)
        menuBtn.lineWidth = 1
        menuBtn.position = CGPoint(x: 0, y: -120)
        menuBtn.name = "menu"
        overlay.addChild(menuBtn)
        
        let menuLabel = SKLabelNode(text: "返回菜单")
        menuLabel.fontName = "Menlo"
        menuLabel.fontSize = 16
        menuLabel.fontColor = SKColor(white: 0.8, alpha: 1)
        menuLabel.verticalAlignmentMode = .center
        menuBtn.addChild(menuLabel)
        
        overlay.alpha = 0
        overlay.run(.fadeIn(withDuration: 0.3))
        addChild(overlay)
        
        // Touch handling
        let touchHandler = GameOverTouchHandler(overlay: overlay, scene: self, won: won)
        overlay.userData = ["handler": touchHandler]
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState.phase == .gameOver {
            // Handled by GameOverTouchHandler
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

// GameOverTouchHandler
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
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = touches.first else { return }
        let location = touch.location(in: overlay)
        let node = overlay.atPoint(location)
        
        if node.name == "retry" {
            overlay.run(.fadeOut(withDuration: 0.2)) {
                self.scene.gameState.startNewGame()
            }
        } else if node.name == "menu" {
            overlay.run(.fadeOut(withDuration: 0.2)) {
                self.scene.gameState.phase = .menu
            }
        }
    }
}

// Supporting UI Nodes

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

class ShellDisplayNode: SKNode {
    private let type: ShellType
    private let body: SKSpriteNode
    private let primer: SKSpriteNode
    private let glow: SKSpriteNode?
    private let indexLabel: SKLabelNode
    
    init(type: ShellType, index: Int) {
        self.type = type
        
        let shellColor = type == .live ? 0xFF2222 : 0xDDDD33
        self.body = SKSpriteNode(texture: SKTexture.fromColor(shellColor, size: CGSize(width: 16, height: 32)))
        
        let primerColor = type == .live ? 0xAA0000 : 0xAAAA00
        self.primer = SKSpriteNode(texture: SKTexture.fromColor(primerColor, size: CGSize(width: 12, height: 6)))
        self.primer.position = CGPoint(x: 0, y: -16)
        
        self.indexLabel = SKLabelNode(text: "\(index + 1)")
        self.indexLabel.fontName = "Menlo-Bold"
        self.indexLabel.fontSize = 8
        self.indexLabel.fontColor = SKColor(white: 0.5, alpha: 1)
        self.indexLabel.position = CGPoint(x: 0, y: 22)
        
        if type == .live {
            self.glow = SKSpriteNode(color: .red, size: CGSize(width: 24, height: 36))
            self.glow!.alpha = 0.3
            self.glow!.zPosition = -1
            self.glow!.blendMode = .add
        } else {
            self.glow = nil
        }
        
        super.init()
        
        addChild(body)
        addChild(primer)
        addChild(indexLabel)
        if let glow = glow { addChild(glow) }
        
        setScale(0.9)
    }
    
    func setState(isCurrent: Bool, isPast: Bool, known: ShellType?) {
        if isPast {
            body.alpha = 0.3
            primer.alpha = 0.3
            glow?.alpha = 0
            run(.scale(to: 0.7, duration: 0.2))
        } else if isCurrent {
            body.alpha = 1
            primer.alpha = 1
            run(.scale(to: 1.1, duration: 0.2))
            
            if known != nil {
                let color = known! == .live ? 0xFF2222 : 0xDDDD33
                body.texture = SKTexture.fromColor(color, size: body.size)
                let primerColor = known! == .live ? 0xAA0000 : 0xAAAA00
                primer.texture = SKTexture.fromColor(primerColor, size: primer.size)
                
                let pulseAction = SKAction.repeatForever(SKAction.sequence([
                    SKAction.scale(to: 1.15, duration: 0.5),
                    SKAction.scale(to: 1.0, duration: 0.5)
                ]))
                run(pulseAction, withKey: "pulse")
            } else {
                removeAction(forKey: "pulse")
            }
        } else {
            body.alpha = 0.6
            primer.alpha = 0.6
            run(.scale(to: 0.9, duration: 0.2))
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

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

class ItemDisplayNode: SKSpriteNode {
    let item: Item
    let isPlayer: Bool
    private let iconLabel: SKLabelNode
    private let nameLabel: SKLabelNode
    private let border: SKShapeNode
    
    init(item: Item, isPlayer: Bool, size: CGSize = CGSize(width: 70, height: 90)) {
        self.item = item
        self.isPlayer = isPlayer
        
        self.iconLabel = SKLabelNode(text: item.type.iconName)
        self.nameLabel = SKLabelNode(text: item.type.displayName)
        
        let bgTexture = SKTexture.fromColor(0x1A0A1A, size: size)
        self.border = SKShapeNode(rectOf: size, cornerRadius: 8)
        
        super.init(texture: bgTexture, color: .clear, size: size)
        
        setup()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private func setup() {
        name = "item_\(item.id.uuidString)"
        zPosition = 1
        isUserInteractionEnabled = isPlayer && !item.used
        
        // Border
        border.strokeColor = SKColor(hex: item.type.color, alpha: item.used ? 0.3 : 0.8)
        border.lineWidth = item.used ? 1 : 2
        border.fillColor = .clear
        border.zPosition = -1
        addChild(border)
        
        // Icon
        iconLabel.fontName = "SF Pro Text"
        iconLabel.fontSize = 28
        iconLabel.fontColor = SKColor(hex: item.type.color)
        iconLabel.verticalAlignmentMode = .center
        iconLabel.position = CGPoint(x: 0, y: 12)
        iconLabel.zPosition = 1
        addChild(iconLabel)
        
        // Name
        nameLabel.fontName = "Menlo-Bold"
        nameLabel.fontSize = 9
        nameLabel.fontColor = SKColor(white: 0.9, alpha: item.used ? 0.4 : 1)
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: -28)
        nameLabel.zPosition = 1
        addChild(nameLabel)
        
        // Used overlay
        if item.used {
            addUsedOverlay()
        }
        
        // Glow
        if !item.used && isPlayer {
            let glow = SKShapeNode(rectOf: CGSize(width: size.width + 8, height: size.height + 8), cornerRadius: 12)
            glow.strokeColor = SKColor(hex: item.type.color, alpha: 0.5)
            glow.lineWidth = 3
            glow.fillColor = .clear
            glow.zPosition = -2
            addChild(glow)
            glow.run(.repeatForever(.sequence([
                .fadeAlpha(to: 0.3, duration: 1),
                .fadeAlpha(to: 0.8, duration: 1)
            ])))
        }
    }
    
    private func addUsedOverlay() {
        let overlay = SKShapeNode(rectOf: CGSize(width: size.width - 4, height: size.height - 4), cornerRadius: 6)
        overlay.fillColor = SKColor(white: 0, alpha: 0.6)
        overlay.strokeColor = .clear
        overlay.zPosition = 2
        addChild(overlay)
        
        let usedLabel = SKLabelNode(text: "已用")
        usedLabel.fontName = "Menlo-Bold"
        usedLabel.fontSize = 11
        usedLabel.fontColor = .gray
        usedLabel.verticalAlignmentMode = .center
        overlay.addChild(usedLabel)
    }
    
    func markUsed() {
        item.used = true
        addUsedOverlay()
        border.strokeColor = SKColor(hex: item.type.color, alpha: 0.3)
        border.lineWidth = 1
        iconLabel.fontColor = SKColor(hex: item.type.color, alpha: 0.4)
        nameLabel.fontColor = SKColor(white: 0.9, alpha: 0.4)
        isUserInteractionEnabled = false
        run(.sequence([.scale(to: 0.9, duration: 0.1), .scale(to: 1.0, duration: 0.1)]))
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !item.used else { return }
        run(.scale(to: 1.1, duration: 0.1))
        border.lineWidth = 3
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard !item.used else { return }
        run(.scale(to: 1.0, duration: 0.1))
        border.lineWidth = 2
        
        if let touch = touches.first {
            let location = touch.location(in: self)
            if self.contains(location) {
                NotificationCenter.default.post(name: .itemTapped, object: item)
            }
        }
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        run(.scale(to: 1.0, duration: 0.1))
        border.lineWidth = 2
    }
}

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
    
    func setRound(_ round: Int, total: Int = 3) {
        roundLabel.text = "回合 \(round)/\(total)"
    }
    
    func setShellsRemaining(_ count: Int) {
        shellsLabel.text = "剩余 \(count) 发"
    }
    
    func setTurn(_ turn: GameState.Turn) {
        let text = turn == .player ? "▶ 你的回合" : "▶ 恶魔回合"
        let color = turn == .player ? SKColor(hex: 0x00FF88) : SKColor(hex: 0xFF2244)
        turnLabel.text = text
        turnLabel.fontColor = color
        turnLabel.run(.sequence([.scale(to: 1.2, duration: 0.1), .scale(to: 1.0, duration: 0.1)]))
    }
    
    func setSawActive(_ active: Bool) {
        sawIndicator.text = active ? "🪚 手锯生效 · 伤害×2" : ""
        sawIndicator.run(.sequence([
            .fadeAlpha(to: active ? 1 : 0, duration: 0.2),
            .scale(to: active ? 1.1 : 1.0, duration: 0.2)
        ]))
    }
}

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
            glow.run(.repeatForever(.sequence([
                .scale(to: 1.2, duration: 0.8),
                .scale(to: 1.0, duration: 0.8)
            ])))
            addChild(glow)
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

class LogNode: SKNode {
    private var logLabels: [SKLabelNode] = []
    private let maxLines = 12
    
    override init() {
        super.init()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    func setLog(_ messages: [String]) {
        // Remove excess
        while logLabels.count > maxLines {
            logLabels.removeFirst().removeFromParent()
        }
        
        // Update existing or add new
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
            
            // Color based on content
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
        
        // Remove old
        while logLabels.count > recent.count {
            logLabels.removeLast().removeFromParent()
        }
    }
}

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
            run(.sequence([.fadeOut(withDuration: 0.2), .removeFromParent()]))
        }
    }
}

// SKColor helper
extension SKColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
    
    func withAlphaComponent(_ alpha: CGFloat) -> SKColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return SKColor(red: r, green: g, blue: b, alpha: alpha)
    }
}

// Notification names
extension Notification.Name {
    static let itemTapped = Notification.Name("itemTapped")
    static let shootSelf = Notification.Name("shootSelf")
    static let shootDealer = Notification.Name("shootDealer")
    static let discardItem = Notification.Name("discardItem")
}