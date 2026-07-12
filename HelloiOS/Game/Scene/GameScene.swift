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
        glow1.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.12, duration: 3),
            SKAction.fadeAlpha(to: 0.05, duration: 3)
        ])))
        
        let glow2 = SKSpriteNode(color: SKColor(hex: 0x002244, alpha: 0.06), size: CGSize(width: 350, height: 350))
        glow2.position = CGPoint(x: 180, y: 220)
        glow2.zPosition = -10
        glow2.blendMode = .add
        addChild(glow2)
        glow2.run(SKAction.repeatForever(SKAction.sequence([
            SKAction.fadeAlpha(to: 0.1, duration: 4),
            SKAction.fadeAlpha(to: 0.03, duration: 4)
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
        overlay.run(SKAction.fadeIn(withDuration: 0.2))
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
        label.run(SKAction.sequence([
            SKAction.group([SKAction.fadeIn(withDuration: 0.2), SKAction.moveBy(x: 0, y: 20, duration: 0.2)]),
            SKAction.wait(forDuration: 3),
            SKAction.group([SKAction.fadeOut(withDuration: 0.3), SKAction.moveBy(x: 0, y: 20, duration: 0.3)]),
            SKAction.removeFromParent()
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
        overlay.run(SKAction.fadeIn(withDuration: 0.3))
        addChild(overlay)
        
        overlay.isUserInteractionEnabled = true
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        if gameState.phase == .gameOver {
            guard let touch = touches.first else { return }
            let location = touch.location(in: self)
            let node = atPoint(location)
            
            if node.name == "retry" {
                run(SKAction.sequence([
                    SKAction.run { self.showGameOver() },
                    SKAction.run { self.removeAllChildren() },
                    SKAction.run { self.gameState.startNewGame() }
                ]))
                return
            } else if node.name == "menu" {
                gameState.phase = .menu
                return
            }
            return
        }
        
        if gameState.phase == .menu {
            gameState.startNewGame()
            return
        }
        
        if let overlay = magnifierOverlay {
            let loc = touches.first?.location(in: self) ?? .zero
            if !overlay.contains(loc) {
                overlay.run(SKAction.sequence([SKAction.fadeOut(withDuration: 0.2), SKAction.removeFromParent()]))
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