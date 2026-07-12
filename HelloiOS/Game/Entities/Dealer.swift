// Game/Entities/Dealer.swift
import SpriteKit
import GameplayKit

class DealerNode: SKNode {
    private let body: SKSpriteNode
    private let face: SKSpriteNode
    private let eyes: SKNode
    private let hat: SKSpriteNode
    private let cards: SKNode
    
    // Animation state
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
        
        // Left eye
        let leftEye = SKSpriteNode(texture: SKTexture.fromColor(0xFFFFEE, size: CGSize(width: 18, height: 24)))
        leftEye.position = CGPoint(x: -22, y: 0)
        leftEye.name = "left_eye"
        container.addChild(leftEye)
        
        let leftPupil = SKSpriteNode(texture: SKTexture.fromColor(0x220044, size: CGSize(width: 8, height: 16)))
        leftPupil.position = CGPoint(x: 0, y: 0)
        leftPupil.name = "left_pupil"
        leftEye.addChild(leftPupil)
        
        // Right eye
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
        
        // Three face-down cards
        for i in 0..<3 {
            let card = SKSpriteNode(texture: SKTexture.fromColor(0x0A001A, size: CGSize(width: 36, height: 52)))
            card.position = CGPoint(x: CGFloat(i - 1) * 40, y: 0)
            card.zRotation = CGFloat(i - 1) * 0.1
            card.zPosition = CGFloat(i)
            container.addChild(card)
            
            // Border
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
        
        // Subtle breathing
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
        
        // Animate in
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

extension Notification.Name {
    static let itemTapped = Notification.Name("itemTapped")
    static let shootSelf = Notification.Name("shootSelf")
    static let shootDealer = Notification.Name("shootDealer")
    static let discardItem = Notification.Name("discardItem")
}