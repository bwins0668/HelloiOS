// Game/Entities/Shotgun.swift
import SpriteKit

// Uses ShellType from GameData.swift

class ShotgunNode: SKNode {
    private let body: SKSpriteNode
    private let barrel: SKSpriteNode
    private let trigger: SKSpriteNode
    private let hammer: SKSpriteNode
    private let chamber: SKSpriteNode
    private var shellDisplayNodes: [ShellDisplayNode] = []
    private var currentIndex: Int = 0
    
    override init() {
        self.body = ShotgunNode.makeBody()
        self.barrel = ShotgunNode.makeBarrel()
        self.trigger = ShotgunNode.makeTrigger()
        self.hammer = ShotgunNode.makeHammer()
        self.chamber = ShotgunNode.makeChamber()
        
        super.init()
        
        setupHierarchy()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private static func makeBody() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x2A1A1A, size: CGSize(width: 90, height: 28))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_body"
        node.zPosition = 10
        return node
    }
    
    private static func makeBarrel() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x1A1010, size: CGSize(width: 140, height: 12))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_barrel"
        node.anchorPoint = CGPoint(x: 0, y: 0.5)
        node.position = CGPoint(x: 35, y: 0)
        node.zPosition = 9
        return node
    }
    
    private static func makeTrigger() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x3A2A2A, size: CGSize(width: 14, height: 22))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_trigger"
        node.position = CGPoint(x: -12, y: -17)
        node.zPosition = 11
        return node
    }
    
    private static func makeHammer() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x4A3A3A, size: CGSize(width: 12, height: 26))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_hammer"
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = CGPoint(x: -35, y: 10)
        node.zPosition = 12
        return node
    }
    
    private static func makeChamber() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x1A1010, size: CGSize(width: 44, height: 22))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_chamber"
        node.position = CGPoint(x: -20, y: 8)
        node.zPosition = 8
        return node
    }
    
    private func setupHierarchy() {
        addChild(body)
        body.addChild(barrel)
        body.addChild(trigger)
        body.addChild(hammer)
        body.addChild(chamber)
        
        let indicator = SKShapeNode(rectOf: CGSize(width: 36, height: 16), cornerRadius: 2)
        indicator.fillColor = SKColor(white: 0.08, alpha: 1)
        indicator.strokeColor = SKColor(white: 0.3, alpha: 1)
        indicator.lineWidth = 1
        indicator.position = CGPoint(x: -20, y: 8)
        indicator.zPosition = 9
        indicator.name = "chamber_indicator"
        body.addChild(indicator)
    }
    
    // MARK: - Public Animation API
    
    func prepareDealAnimation(shells: [ShellType]) {
        shellDisplayNodes.forEach { $0.removeFromParent() }
        shellDisplayNodes.removeAll()
        
        let slotWidth: CGFloat = 36
        let startX = -CGFloat(shells.count - 1) * slotWidth / 2
        
        for (i, type) in shells.enumerated() {
            let shellNode = ShellDisplayNode(type: type, index: i)
            shellNode.position = CGPoint(x: startX + CGFloat(i) * slotWidth, y: 8)
            shellNode.zPosition = 15
            shellNode.alpha = 0
            body.addChild(shellNode)
            shellDisplayNodes.append(shellNode)
            
            let delay = Double(i) * 0.15
            shellNode.run(.sequence([
                .wait(forDuration: delay),
                .group([
                    .fadeIn(withDuration: 0.2),
                    .scale(to: 1.1, duration: 0.15),
                    .scale(to: 1.0, duration: 0.1)
                ])
            ]))
        }
        
        currentIndex = 0
    }
    
    func updateShellDisplay(shells: [ShellType], index: Int, known: ShellType?) {
        currentIndex = index
        
        for (i, node) in shellDisplayNodes.enumerated() {
            let isCurrent = i == index
            let isPast = i < index
            node.setState(isCurrent: isCurrent, isPast: isPast, known: isCurrent ? known : nil)
        }
    }
    
    func setKnownShell(_ known: ShellType?) {
        // handled in updateShellDisplay
    }
    
    func setSawActive(_ active: Bool) {
        // visual indicator on shotgun
    }
    
    func aimAtDealer(completion: @escaping () -> Void) {
        run(.rotate(toAngle: .pi/2 + 0.3, duration: 0.3), completion: completion)
    }
    
    func aimAtSelf(completion: @escaping () -> Void) {
        run(.rotate(toAngle: -.pi/2 - 0.3, duration: 0.3), completion: completion)
    }
    
    func fire(isLive: Bool, completion: @escaping () -> Void) {
        // Muzzle flash
        let flash = SKSpriteNode(color: .white, size: CGSize(width: 60, height: 20))
        flash.position = CGPoint(x: 85, y: 0)
        flash.zPosition = 20
        flash.alpha = 0
        body.addChild(flash)
        
        let flashSeq = SKAction.sequence([
            .fadeAlpha(to: 1, duration: 0.01),
            .wait(forDuration: 0.05),
            .fadeOut(withDuration: 0.1),
            .removeFromParent()
        ])
        flash.run(flashSeq)
        
        // Recoil
        let recoil = SKAction.sequence([
            .moveBy(x: -20, duration: 0.05),
            .moveBy(x: 20, duration: 0.15)
        ])
        recoil.timingMode = .easeOut
        body.run(recoil)
        
        // Hammer strike
        hammer.run(.sequence([
            .rotate(toAngle: -.pi/4, duration: 0.02),
            .rotate(toAngle: 0, duration: 0.08)
        ]))
        
        // Shell casing eject
        if isLive && currentIndex - 1 >= 0 && currentIndex - 1 < shellDisplayNodes.count {
            let casing = ShellDisplayNode.casing()
            casing.position = shellDisplayNodes[currentIndex - 1].position
            casing.zPosition = 16
            body.addChild(casing)
            
            let eject = SKAction.group([
                .moveBy(x: CGFloat.random(in: 40...80), y: CGFloat.random(in: 20...50), duration: 0.4),
                .rotate(byAngle: .pi * 2, duration: 0.4),
                .sequence([.wait(forDuration: 0.3), .fadeOut(withDuration: 0.2)])
            ])
            casing.run(.sequence([eject, .removeFromParent()]))
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: completion)
    }
    
    func resetRotation() {
        run(.rotate(toAngle: 0, duration: 0.3))
    }
}

// Shell Display Node
class ShellDisplayNode: SKNode {
    let type: ShellType
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
            
            if let known = known {
                let color = known == .live ? 0xFF2222 : 0xDDDD33
                body.texture = SKTexture.fromColor(color, size: body.size)
                let primerColor = known == .live ? 0xAA0000 : 0xAAAA00
                primer.texture = SKTexture.fromColor(primerColor, size: primer.size)
                
                run(.repeatForever(.sequence([
                    .scale(to: 1.15, duration: 0.5),
                    .scale(to: 1.0, duration: 0.5)
                ]), withKey: "pulse")
            } else {
                removeAction(forKey: "pulse")
            }
        } else {
            body.alpha = 0.6
            primer.alpha = 0.6
            run(.scale(to: 0.9, duration: 0.2))
        }
    }
    
    static func casing() -> SKNode {
        let node = SKNode()
        let body = SKSpriteNode(texture: SKTexture.fromColor(0xCCAA66, size: CGSize(width: 8, height: 16)))
        let primer = SKSpriteNode(texture: SKTexture.fromColor(0x886622, size: CGSize(width: 6, height: 4)))
        primer.position = CGPoint(x: 0, y: -8)
        node.addChild(body)
        node.addChild(primer)
        return node
    }
    
    required init?(coder: NSCoder) { fatalError() }
}