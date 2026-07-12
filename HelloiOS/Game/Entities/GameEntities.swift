// Game/Entities/GameEntities.swift
import SpriteKit

// MARK: - SKColor Helper
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

// MARK: - SKTexture Helper
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

// MARK: - Shell Display Node
class ShellDisplayNode: SKNode {
    let type: ShellType
    private let shell: SKSpriteNode
    private let primer: SKSpriteNode
    private let glow: SKSpriteNode?
    private let indexLabel: SKLabelNode
    
    init(type: ShellType, index: Int) {
        self.type = type
        
        let shellColor: UInt32 = type == .live ? 0xFF2222 : 0xDDDD33
        self.shell = SKSpriteNode(texture: SKTexture.fromColor(shellColor, size: CGSize(width: 16, height: 32)))
        
        let primerColor: UInt32 = type == .live ? 0xAA0000 : 0xAAAA00
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
        
        addChild(shell)
        addChild(primer)
        addChild(indexLabel)
        if let glow = glow { addChild(glow) }
        
        setScale(0.9)
    }
    
    func setState(isCurrent: Bool, isPast: Bool, known: ShellType?) {
        let displayType = known ?? type
        
        if isPast {
            shell.alpha = 0.3
            primer.alpha = 0.3
            glow?.alpha = 0
            run(.scale(to: 0.7, duration: 0.2))
        } else if isCurrent {
            shell.alpha = 1
            primer.alpha = 1
            run(.scale(to: 1.1, duration: 0.2))
            
            if known != nil {
                let color = displayType == .live ? 0xFF2222 : 0xDDDD33
                shell.texture = SKTexture.fromColor(color, size: shell.size)
                let primerColor = displayType == .live ? 0xAA0000 : 0xAAAA00
                primer.texture = SKTexture.fromColor(primerColor, size: primer.size)
                
                run(.repeatForever(.sequence([
                    .scale(to: 1.15, duration: 0.5),
                    .scale(to: 1.0, duration: 0.5)
                ])), withKey: "pulse")
            } else {
                removeAction(forKey: "pulse")
            }
        } else {
            shell.alpha = 0.6
            primer.alpha = 0.6
            run(.scale(to: 0.9, duration: 0.2))
        }
    }
    
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - Shotgun Node
class ShotgunNode: SKNode {
    private let body: SKSpriteNode
    private let barrel: SKSpriteNode
    private let trigger: SKSpriteNode
    private let hammer: SKSpriteNode
    private let chamber: SKSpriteNode
    private var shellDisplayNodes: [ShellDisplayNode] = []
    private var currentIndex: Int = 0
    var isAnimating: Bool = false
    
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
    
    func setKnownShell(_ shell: ShellType?) {
        // Handled in updateShellDisplay
    }
    
    func setSawActive(_ active: Bool) {
        if active {
            let sawIcon = SKLabelNode(text: "🪚")
            sawIcon.fontSize = 20
            sawIcon.position = CGPoint(x: -40, y: 30)
            sawIcon.zPosition = 20
            sawIcon.name = "saw_indicator"
            body.addChild(sawIcon)
            sawIcon.run(.repeatForever(.sequence([
                .scale(to: 1.1, duration: 0.5),
                .scale(to: 1.0, duration: 0.5)
            ])))
        } else {
            body.childNode(withName: "saw_indicator")?.removeFromParent()
        }
    }
    
    func rackSlide(completion: @escaping () -> Void) {
        isAnimating = true
        
        let hammerBack = SKAction.rotate(toAngle: -.pi/3, duration: 0.1)
        hammer.run(hammerBack)
        
        let slideBack = SKAction.moveBy(x: -45, duration: 0.15)
        slideBack.timingMode = .easeOut
        
        let ejectShell = SKAction.run { [weak self] in
            self?.ejectCurrentShell()
        }
        
        let slideForward = SKAction.moveBy(x: 45, duration: 0.12)
        slideForward.timingMode = .easeIn
        
        let hammerForward = SKAction.rotate(toAngle: 0, duration: 0.08)
        
        body.run(.sequence([
            slideBack,
            ejectShell,
            slideForward,
            .run { self.isAnimating = false }
        ]))
        
        hammer.run(.sequence([.wait(forDuration: 0.27), hammerForward]))
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: completion)
    }
    
    private func ejectCurrentShell() {
        guard currentIndex < shellDisplayNodes.count else { return }
        let shell = shellDisplayNodes[currentIndex]
        
        let eject = SKAction.group([
            .moveBy(x: CGFloat.random(in: -30...30), y: CGFloat.random(in: 50...90), duration: 0.5),
            .rotate(byAngle: CGFloat.random(in: -1...1), duration: 0.5),
            .fadeOut(withDuration: 0.4)
        ])
        
        shell.run(.sequence([eject, .removeFromParent()]))
        currentIndex += 1
    }
    
    func aimAtSelf(completion: @escaping () -> Void) {
        let rotate = SKAction.rotate(toAngle: -.pi/2 - 0.3, duration: 0.3)
        rotate.timingMode = .easeInOut
        run(rotate, completion: completion)
    }
    
    func aimAtDealer(completion: @escaping () -> Void) {
        let rotate = SKAction.rotate(toAngle: .pi/2 + 0.3, duration: 0.3)
        rotate.timingMode = .easeInOut
        run(rotate, completion: completion)
    }
    
    func fire(isLive: Bool, completion: @escaping () -> Void) {
        // Muzzle flash
        let flash = SKSpriteNode(color: .white, size: CGSize(width: 80, height: 25))
        flash.position = CGPoint(x: 100, y: 0)
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
            .moveBy(x: -25, duration: 0.05),
            .moveBy(x: 25, duration: 0.2)
        ])
        recoil.timingMode = .easeOut
        body.run(recoil)
        
        // Hammer strike
        hammer.run(.sequence([
            .rotate(toAngle: -.pi/4, duration: 0.02),
            .rotate(toAngle: 0, duration: 0.08)
        ]))
        
        // Shell casing eject visual
        if isLive && currentIndex - 1 >= 0 && currentIndex - 1 < shellDisplayNodes.count {
            let casing = makeCasing()
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
    
    private func makeCasing() -> SKNode {
        let node = SKNode()
        let body = SKSpriteNode(texture: SKTexture.fromColor(0xCCAA66, size: CGSize(width: 8, height: 16)))
        let primer = SKSpriteNode(texture: SKTexture.fromColor(0x886622, size: CGSize(width: 6, height: 4)))
        primer.position = CGPoint(x: 0, y: -8)
        node.addChild(body)
        node.addChild(primer)
        return node
    }
    
    func resetRotation() {
        run(.rotate(toAngle: 0, duration: 0.3))
    }
}

// MARK: - Dealer Node
class DealerNode: SKNode {
    private let body: SKSpriteNode
    private let face: SKSpriteNode
    private let eyes: SKNode
    private let hat: SKSpriteNode
    private let cards: SKNode
    
    var currentMood: DealerMood = .neutral
    private var blinkTimer: Timer?
    
    override init() {
        self.body = DealerNode.makeBody()
        self.face = DealerNode.makeFace()
        self.eyes = DealerNode.makeEyes()
        self.hat = DealerNode.makeHat()
        self.cards = DealerNode.makeCards()
        
        super.init()
        setupHierarchy()
        startBlinking()
    }
    
    required init?(coder: NSCoder) { fatalError() }
    
    private static func makeBody() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x1A0A1A, size: CGSize(width: 140, height: 180))
        let node = SKSpriteNode(texture: texture)
        node.name = "dealer_body"
        node.zPosition = 20
        return node
    }
    
    private static func makeFace() -> SKSpriteNode {
        let texture = SKTexture.fromColor(0x2A0A2A, size: CGSize(width: 100, height: 100))
        let node = SKSpriteNode(texture: texture)
        node.name = "dealer_face"
        node.position = CGPoint(x: 0, y: 30)
        node.zPosition = 21
        return node
    }
    
    private static func makeEyes() -> SKNode {
        let container = SKNode()
        container.name = "dealer_eyes"
        container.position = CGPoint(x: 0, y: 40)
        container.zPosition = 22
        
        let leftEye = SKSpriteNode(texture: SKTexture.fromColor(0xFFFFEE, size: CGSize(width: 18, height: 24)))
        leftEye.position = CGPoint(x: -22, y: 0)
        leftEye.name = "left_eye"
        container.addChild(leftEye)
        
        let leftPupil = SKSpriteNode(texture: SKTexture.fromColor(0x220044, size: CGSize(width: 8, height: 16)))
        leftPupil.position = CGPoint(x: 0, y: 0)
        leftPupil.name = "left_pupil"
        leftEye.addChild(leftPupil)
        
        let rightEye = SKSpriteNode(texture: SKTexture.fromColor(0xFFFFEE, size: CGSize(width: 18, height: 24)))
        rightEye.position = CGPoint(x: 22, y: 0)
        rightEye.name = "right_eye"
        container.addChild(rightEye)
        
        let rightPupil = SKSpriteNode(texture: SKTexture.fromColor(0x220044, size: CGSize(width: 8, height: 16)))
        rightPupil.position = CGPoint(x: 0, y: 0)
        rightPupil.name = "right_pupil"
        rightEye.addChild(rightPupil)
        
        return container
    }
    
    private static func makeHat() -> SKSpriteNode {
        let brim = SKSpriteNode(texture: SKTexture.fromColor(0x0A000A, size: CGSize(width: 130, height: 12)))
        brim.position = CGPoint(x: 0, y: 85)
        brim.zPosition = 23
        return brim
    }
    
    private static func makeCards() -> SKNode {
        let container = SKNode()
        container.name = "dealer_cards"
        container.position = CGPoint(x: 0, y: -90)
        container.zPosition = 19
        
        for i in 0..<3 {
            let card = SKSpriteNode(texture: SKTexture.fromColor(0x0A001A, size: CGSize(width: 36, height: 52)))
            card.position = CGPoint(x: CGFloat(i - 1) * 40, y: 0)
            card.zRotation = CGFloat(i - 1) * 0.1
            card.zPosition = CGFloat(i)
            container.addChild(card)
            
            let border = SKShapeNode(rectOf: CGSize(width: 36, height: 52), cornerRadius: 4)
            border.strokeColor = SKColor(hex: 0xAA00AA, alpha: 0.5)
            border.lineWidth = 2
            border.fillColor = .clear
            card.addChild(border)
        }
        return container
    }
    
    private func setupHierarchy() {
        addChild(body)
        body.addChild(face)
        face.addChild(eyes)
        body.addChild(hat)
        addChild(cards)
        
        let breathe = SKAction.sequence([
            .scaleY(to: 1.01, duration: 2.5),
            .scaleY(to: 0.99, duration: 2.5)
        ])
        body.run(.repeatForever(breathe))
    }
    
    private func startBlinking() {
        blinkTimer = Timer.scheduledTimer(withTimeInterval: Double.random(in: 3...6), repeats: true) { [weak self] _ in
            self?.blink()
        }
    }
    
    private func blink() {
        guard let leftEye = eyes.childNode(withName: "left_eye") as? SKSpriteNode,
              let rightEye = eyes.childNode(withName: "right_eye") as? SKSpriteNode else { return }
        
        let blinkAction = SKAction.sequence([
            .scaleY(to: 0.1, duration: 0.08),
            .scaleY(to: 1.0, duration: 0.08)
        ])
        leftEye.run(blinkAction)
        rightEye.run(blinkAction)
    }
    
    // MARK: - Mood Expressions
    
    func setMood(_ mood: DealerMood) {
        currentMood = mood
        applyMood(mood)
    }
    
    private func applyMood(_ mood: DealerMood) {
        guard let leftEye = eyes.childNode(withName: "left_eye") as? SKSpriteNode,
              let rightEye = eyes.childNode(withName: "right_eye") as? SKSpriteNode,
              let leftPupil = leftEye.childNode(withName: "left_pupil") as? SKSpriteNode,
              let rightPupil = rightEye.childNode(withName: "right_pupil") as? SKSpriteNode else { return }
        
        let eyeColor: UInt32
        let pupilHeight: CGFloat
        let pupilColor: UInt32
        
        switch mood {
        case .neutral:
            eyeColor = 0xFFFFEE; pupilHeight = 16; pupilColor = 0x220044
        case .thinking:
            eyeColor = 0xEEEECC; pupilHeight = 10; pupilColor = 0x440066
            face.run(.rotate(toAngle: -0.05, duration: 0.3))
        case .amused:
            eyeColor = 0xFFEEAA; pupilHeight = 6; pupilColor = 0x660022
            wiggleCards()
        case .annoyed:
            eyeColor = 0xFFCCCC; pupilHeight = 4; pupilColor = 0x880000
            face.run(.rotate(toAngle: 0.08, duration: 0.2))
        case .surprised:
            eyeColor = 0xFFFFFF; pupilHeight = 20; pupilColor = 0x000044
            leftEye.run(.scale(to: 1.2, duration: 0.1))
            rightEye.run(.scale(to: 1.2, duration: 0.1))
        case .dead:
            eyeColor = 0x333333; pupilHeight = 2; pupilColor = 0x111111
            face.run(.rotate(toAngle: 0.3, duration: 0.5))
            hat.run(.moveBy(x: 10, y: -30, duration: 0.5))
        }
        
        let eyeTex = SKTexture.fromColor(eyeColor, size: leftEye.size)
        leftEye.texture = eyeTex
        rightEye.texture = eyeTex
        
        let pupilTex = SKTexture.fromColor(pupilColor, size: CGSize(width: 8, height: pupilHeight))
        leftPupil.texture = pupilTex
        rightPupil.texture = pupilTex
        
        leftPupil.run(.resize(toHeight: pupilHeight, duration: 0.2))
        rightPupil.run(.resize(toHeight: pupilHeight, duration: 0.2))
    }
    
    private func wiggleCards() {
        for (i, card) in cards.children.enumerated() {
            let delay = Double(i) * 0.05
            card.run(.sequence([
                .wait(forDuration: delay),
                .rotate(byAngle: 0.15, duration: 0.15),
                .rotate(byAngle: -0.3, duration: 0.3),
                .rotate(byAngle: 0.15, duration: 0.15)
            ]))
        }
    }
    
    func dealCardAnimation(to position: CGPoint, completion: @escaping () -> Void) {
        guard let card = cards.children.first else { completion(); return }
        cards.children.removeFirst()
        
        let targetPos = convert(position, from: parent!)
        let fly = SKAction.group([
            .move(to: targetPos, duration: 0.4),
            .rotate(byAngle: .pi * 1.5, duration: 0.4),
            .scale(to: 0.6, duration: 0.4)
        ])
        fly.timingMode = .easeOut
        
        card.run(.sequence([fly, .run(completion)]))
    }
    
    func speechBubble(_ text: String) -> SKNode {
        let bubble = SKNode()
        bubble.zPosition = 30
        
        let label = SKLabelNode(text: text)
        label.fontName = "Menlo-Bold"
        label.fontSize = 14
        label.fontColor = SKColor(hex: 0xFFEEAA)
        label.numberOfLines = 0
        label.preferredMaxLayoutWidth = 200
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        
        let padding: CGFloat = 16
        let bg = SKShapeNode(rectOf: CGSize(width: label.frame.width + padding * 2,
                                             height: label.frame.height + padding),
                             cornerRadius: 12)
        bg.fillColor = SKColor(hex: 0x1A001A, alpha: 0.95)
        bg.strokeColor = SKColor(hex: 0xAA00AA, alpha: 0.8)
        bg.lineWidth = 2
        bg.addChild(label)
        
        // Tail
        let tail = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -12, y: -bg.frame.height/2))
        path.addLine(to: CGPoint(x: 0, y: -bg.frame.height/2 - 14))
        path.addLine(to: CGPoint(x: 12, y: -bg.frame.height/2))
        tail.path = path
        tail.fillColor = SKColor(hex: 0x1A001A, alpha: 0.95)
        tail.strokeColor = SKColor(hex: 0xAA00AA, alpha: 0.8)
        tail.lineWidth = 2
        bg.addChild(tail)
        
        bubble.addChild(bg)
        bubble.position = CGPoint(x: 0, y: 140)
        
        bubble.setScale(0)
        bubble.run(.sequence([
            .scale(to: 1.1, duration: 0.2),
            .scale(to: 1.0, duration: 0.1),
            .wait(forDuration: 2.5),
            .fadeOut(withDuration: 0.3),
            .removeFromParent()
        ]))
        
        return bubble
    }
    
    func cleanup() {
        blinkTimer?.invalidate()
        blinkTimer = nil
        removeAllActions()
        children.forEach { $0.removeAllActions() }
    }
}

// MARK: - Item Display Node
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
        zPosition = 40
        isUserInteractionEnabled = isPlayer && !item.used
        
        border.strokeColor = SKColor(hex: item.type.color, alpha: item.used ? 0.3 : 0.8)
        border.lineWidth = item.used ? 1 : 2
        border.fillColor = .clear
        border.zPosition = -1
        addChild(border)
        
        iconLabel.fontName = "SF Pro Text"
        iconLabel.fontSize = 28
        iconLabel.fontColor = SKColor(hex: item.type.color)
        iconLabel.verticalAlignmentMode = .center
        iconLabel.position = CGPoint(x: 0, y: 12)
        iconLabel.zPosition = 1
        addChild(iconLabel)
        
        nameLabel.fontName = "Menlo-Bold"
        nameLabel.fontSize = 9
        nameLabel.fontColor = SKColor(white: 0.9, alpha: item.used ? 0.4 : 1)
        nameLabel.verticalAlignmentMode = .center
        nameLabel.position = CGPoint(x: 0, y: -28)
        nameLabel.zPosition = 1
        addChild(nameLabel)
        
        if item.used { addUsedOverlay() }
        
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