// Game/Entities/Shotgun.swift
import SpriteKit

class ShotgunNode: SKNode {
    private let body: SKSpriteNode
    private let barrel: SKSpriteNode
    private let trigger: SKSpriteNode
    private let hammer: SKSpriteNode
    private let chamber: SKSpriteNode
    private var shells: [ShellNode] = []
    
    // Animation states
    var isRacked: Bool = false
    var currentShellIndex: Int = 0
    
    override init() {
        // Build shotgun from procedural shapes (no external assets needed)
        self.body = ShotgunNode.makeBody()
        self.barrel = ShotgunNode.makeBarrel()
        self.trigger = ShotgunNode.makeTrigger()
        self.hammer = ShotgunNode.makeHammer()
        self.chamber = ShotgunNode.makeChamber()
        
        super.init()
        
        setupHierarchy()
        setupPhysics()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private static func makeBody() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x2A1A1A, size: CGSize(width: 80, height: 24))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_body"
        node.zPosition = 10
        return node
    }
    
    private static func makeBarrel() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x1A1010, size: CGSize(width: 120, height: 10))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_barrel"
        node.anchorPoint = CGPoint(x: 0, y: 0.5)
        node.position = CGPoint(x: 30, y: 0)
        node.zPosition = 9
        return node
    }
    
    private static func makeTrigger() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x3A2A2A, size: CGSize(width: 12, height: 18))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_trigger"
        node.position = CGPoint(x: -10, y: -14)
        node.zPosition = 11
        return node
    }
    
    private static func makeHammer() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x4A3A3A, size: CGSize(width: 10, height: 22))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_hammer"
        node.anchorPoint = CGPoint(x: 0.5, y: 0)
        node.position = CGPoint(x: -30, y: 8)
        node.zPosition = 12
        return node
    }
    
    private static func makeChamber() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x1A1010, size: CGSize(width: 36, height: 18))
        let node = SKSpriteNode(texture: texture)
        node.name = "shotgun_chamber"
        node.position = CGPoint(x: -18, y: 6)
        node.zPosition = 8
        return node
    }
    
    private func setupHierarchy() {
        addChild(body)
        body.addChild(barrel)
        body.addChild(trigger)
        body.addChild(hammer)
        body.addChild(chamber)
        
        // Chamber interior indicator
        let indicator = SKShapeNode(rectOf: CGSize(width: 28, height: 12), cornerRadius: 2)
        indicator.fillColor = SKColor(white: 0.08, alpha: 1)
        indicator.strokeColor = SKColor(white: 0.3, alpha: 1)
        indicator.lineWidth = 1
        indicator.position = CGPoint(x: -18, y: 6)
        indicator.zPosition = 9
        indicator.name = "chamber_indicator"
        body.addChild(indicator)
    }
    
    private func setupPhysics() {
        body.physicsBody = SKPhysicsBody(rectangleOf: body.size)
        body.physicsBody?.isDynamic = false
        body.physicsBody?.categoryBitMask = 0x1
        body.physicsBody?.contactTestBitMask = 0
    }
    
    // MARK: - Public Animation API
    
    func loadShells(_ types: [ShellType]) {
        // Clear existing
        shells.forEach { $0.removeFromParent() }
        shells.removeAll()
        
        let slotWidth: CGFloat = 32
        let startX: CGFloat = -CGFloat(types.count - 1) * slotWidth / 2
        
        for (i, type) in types.enumerated() {
            let shell = ShellNode(type: type)
            shell.position = CGPoint(x: startX + CGFloat(i) * slotWidth, y: 8)
            shell.zPosition = 15
            shell.alpha = 0
            body.addChild(shell)
            shells.append(shell)
            
            // Staggered appear
            let delay = Double(i) * 0.15
            shell.run(.sequence([
                .wait(forDuration: delay),
                .group([
                    .fadeIn(withDuration: 0.2),
                    .scale(to: 1.1, duration: 0.15),
                    .scale(to: 1.0, duration: 0.1)
                ])
            ]))
        }
    }
    
    func rackSlide(completion: @escaping () -> Void) {
        isRacked = true
        
        // Hammer cock back
        let hammerBack = SKAction.rotate(toAngle: -.pi/3, duration: 0.1)
        hammer.run(hammerBack)
        
        // Slide back
        let slideBack = SKAction.moveBy(x: -40, duration: 0.15)
        slideBack.timingMode = .easeOut
        
        let ejectShell = SKAction.run { [weak self] in
            self?.ejectCurrentShell()
        }
        
        let slideForward = SKAction.moveBy(x: 40, duration: 0.12)
        slideForward.timingMode = .easeIn
        
        let hammerForward = SKAction.rotate(toAngle: 0, duration: 0.08)
        
        body.run(.sequence([
            slideBack,
            ejectShell,
            slideForward,
            .run { self.isRacked = false }
        ]))
        
        hammer.run(.sequence([.wait(forDuration: 0.27), hammerForward]))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: completion)
    }
    
    private func ejectCurrentShell() {
        guard currentShellIndex < shells.count else { return }
        let shell = shells[currentShellIndex]
        
        let eject = SKAction.group([
            .moveBy(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: 40...80), duration: 0.5),
            .rotate(byAngle: CGFloat.random(in: -1...1), duration: 0.5),
            .fadeOut(withDuration: 0.4)
        ])
        
        shell.run(.sequence([eject, .removeFromParent()]))
        shells[currentShellIndex] = ShellNode.emptyPlaceholder(at: shell.position, parent: body)
        currentShellIndex += 1
    }
    
    func aimAtSelf(completion: @escaping () -> Void) {
        // Point barrel down at player
        let rotate = SKAction.rotate(toAngle: -.pi/2 - 0.3, duration: 0.3)
        rotate.timingMode = .easeInOut
        run(rotate, completion: completion)
    }
    
    func aimAtDealer(completion: @escaping () -> Void) {
        // Point barrel up at dealer
        let rotate = SKAction.rotate(toAngle: .pi/2 + 0.3, duration: 0.3)
        rotate.timingMode = .easeInOut
        run(rotate, completion: completion)
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
        
        // Shell casing eject if live (visual only)
        if isLive && currentShellIndex - 1 >= 0 && currentShellIndex - 1 < shells.count {
            let casing = ShellNode.casing()
            casing.position = shells[currentShellIndex - 1].position
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

// Shell Node
class ShellNode: SKNode {
    let type: ShellType
    private let body: SKSpriteNode
    private let primer: SKSpriteNode
    
    init(type: ShellType) {
        self.type = type
        
        // Shell body
        let shellColor: UInt32 = type == .live ? 0xFF2222 : 0xDDDD33
        let texture = SKTexture.fromColor(shellColor, size: CGSize(width: 14, height: 28))
        self.body = SKSpriteNode(texture: texture)
        
        // Primer
        let primerColor: UInt32 = type == .live ? 0xAA0000 : 0xAAAA00
        let primerTexture = SKTexture.fromColor(primerColor, size: CGSize(width: 10, height: 6))
        self.primer = SKSpriteNode(texture: primerTexture)
        self.primer.position = CGPoint(x: 0, y: -14)
        
        super.init()
        
        addChild(body)
        addChild(primer)
        
        // Live shell glow
        if type == .live {
            let glow = SKSpriteNode(color: .red, size: CGSize(width: 20, height: 32))
            glow.alpha = 0.3
            glow.zPosition = -1
            glow.blendMode = .add
            addChild(glow)
            
            let pulse = SKAction.sequence([
                .fadeAlpha(to: 0.5, duration: 0.6),
                .fadeAlpha(to: 0.2, duration: 0.6)
            ])
            glow.run(.repeatForever(pulse))
        }
        
        setScale(0.8)
    }
    
    static func emptyPlaceholder(at pos: CGPoint, parent: SKNode) -> ShellNode {
        let node = SKNode()
        node.position = pos
        node.zPosition = 15
        let dot = SKShapeNode(circleOfRadius: 3)
        dot.fillColor = SKColor(white: 0.15, alpha: 1)
        dot.strokeColor = SKColor(white: 0.3, alpha: 1)
        dot.lineWidth = 1
        node.addChild(dot)
        parent.addChild(node)
        return ShellNode(type: .blank) // dummy
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

// SKTexture helper
extension SKTexture {
    static func fromColor(_ hex: UInt32, size: CGSize) -> SKTexture {
        let color = SKColor(hex: hex)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
        return SKTexture(image: image)
    }
}

extension SKColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(red: r, green: g, blue: b, alpha: alpha)
    }
}