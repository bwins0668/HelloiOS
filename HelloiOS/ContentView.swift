import SwiftUI
import UIKit

// MARK: - Theme

private enum JumpTheme {
    static let skyTop = Color(red: 0.10, green: 0.14, blue: 0.28)
    static let skyMid = Color(red: 0.16, green: 0.10, blue: 0.32)
    static let skyBottom = Color(red: 0.28, green: 0.18, blue: 0.42)
    static let accent = Color(red: 0.45, green: 0.85, blue: 1.0)
    static let accent2 = Color(red: 0.95, green: 0.55, blue: 0.95)
    static let gold = Color(red: 1.0, green: 0.84, blue: 0.35)
    static let player = Color(red: 1.0, green: 0.45, blue: 0.55)
    static let platform = Color(red: 0.40, green: 0.95, blue: 0.72)
    static let platformMoving = Color(red: 0.55, green: 0.70, blue: 1.0)
    static let platformSpring = Color(red: 1.0, green: 0.75, blue: 0.35)
}

// MARK: - Models

private enum PlatformKind: Equatable {
    case normal
    case moving
    case spring
}

private struct Platform: Identifiable, Equatable {
    let id: UUID
    var x: CGFloat          // center, world
    var y: CGFloat          // top surface, world (y up)
    var width: CGFloat
    var kind: PlatformKind
    var phase: CGFloat      // moving platforms
    var broken: Bool = false
}

private enum Phase: Equatable {
    case menu
    case playing
    case gameOver
}

// MARK: - Engine

@MainActor
private final class JumpEngine: ObservableObject {
    // World: y increases upward. Screen draws with flip.
    @Published var phase: Phase = .menu
    @Published var score: Int = 0
    @Published var best: Int
    @Published var playerX: CGFloat = 0
    @Published var playerY: CGFloat = 0
    @Published var cameraY: CGFloat = 0
    @Published var platforms: [Platform] = []
    @Published var particles: [Particle] = []
    @Published var moveInput: CGFloat = 0 // -1...1
    @Published var flashLanding = false

    private var velX: CGFloat = 0
    private var velY: CGFloat = 0
    private var lastTime: Date?
    private var highestY: CGFloat = 0
    private var nextPlatformY: CGFloat = 0
    private var worldWidth: CGFloat = 390
    private var worldHeight: CGFloat = 844
    private var displayLink: CADisplayLink?
    private let bestKey = "helloios.jump.best"

    // tuning
    private let gravity: CGFloat = 2100
    private let jumpV: CGFloat = 920
    private let springV: CGFloat = 1280
    private let moveAccel: CGFloat = 3200
    private let maxMoveSpeed: CGFloat = 520
    private let airDrag: CGFloat = 0.86
    private let playerR: CGFloat = 18

    struct Particle: Identifiable, Equatable {
        let id: UUID
        var x: CGFloat
        var y: CGFloat
        var vx: CGFloat
        var vy: CGFloat
        var life: CGFloat
        var color: Color
        var size: CGFloat
    }

    init() {
        best = UserDefaults.standard.integer(forKey: bestKey)
    }

    func configure(size: CGSize) {
        worldWidth = max(size.width, 320)
        worldHeight = max(size.height, 568)
    }

    func start() {
        stopLoop()
        score = 0
        highestY = 80
        playerX = worldWidth * 0.5
        playerY = 80
        cameraY = 0
        velX = 0
        velY = jumpV * 0.55
        moveInput = 0
        particles = []
        flashLanding = false
        platforms = []
        nextPlatformY = 20
        seedPlatforms()
        phase = .playing
        lastTime = nil
        startLoop()
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
    }

    func backToMenu() {
        stopLoop()
        phase = .menu
        particles = []
        moveInput = 0
    }

    func setInput(_ x: CGFloat) {
        // x: -1...1
        moveInput = max(-1, min(1, x))
    }

    func endDrag() {
        // keep slight momentum feel: soft release
        moveInput *= 0.2
    }

    private func startLoop() {
        let link = CADisplayLink(target: TickTarget(owner: self), selector: #selector(TickTarget.tick))
        link.preferredFrameRateRange = CAFrameRateRange(minimum: 30, maximum: 120, preferred: 60)
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    private func stopLoop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTime = nil
    }

    fileprivate func step(now: Date) {
        guard phase == .playing else { return }
        let dt: CGFloat
        if let last = lastTime {
            dt = min(CGFloat(now.timeIntervalSince(last)), 1.0 / 20.0)
        } else {
            dt = 1.0 / 60.0
        }
        lastTime = now
        physics(dt: dt)
        updateParticles(dt: dt)
    }

    private func physics(dt: CGFloat) {
        // horizontal
        velX += moveInput * moveAccel * dt
        velX *= pow(airDrag, dt * 60)
        velX = max(-maxMoveSpeed, min(maxMoveSpeed, velX))
        playerX += velX * dt

        // wrap horizontally
        if playerX < -playerR { playerX = worldWidth + playerR }
        if playerX > worldWidth + playerR { playerX = -playerR }

        // vertical
        velY -= gravity * dt
        playerY += velY * dt

        // platform collisions (only when falling)
        if velY < 0 {
            for i in platforms.indices {
                if platforms[i].broken { continue }
                if land(on: platforms[i]) {
                    bounce(on: &platforms[i])
                    break
                }
            }
        }

        // camera follow
        let targetCam = playerY - worldHeight * 0.38
        if targetCam > cameraY {
            cameraY = targetCam
        }

        // score by height
        if playerY > highestY {
            highestY = playerY
            let s = Int(highestY / 10)
            if s != score {
                score = s
                if score > best {
                    best = score
                    UserDefaults.standard.set(best, forKey: bestKey)
                }
            }
        }

        // generate platforms above
        while nextPlatformY < cameraY + worldHeight + 200 {
            spawnPlatform()
        }
        // cull below
        platforms.removeAll { $0.y < cameraY - 120 || $0.broken }

        // animate moving platforms
        for i in platforms.indices where platforms[i].kind == .moving {
            platforms[i].phase += dt
        }

        // death: fall below camera
        if playerY < cameraY - 40 {
            gameOver()
        }
    }

    private func movedX(for p: Platform) -> CGFloat {
        guard p.kind == .moving else { return p.x }
        let amp = min(worldWidth * 0.25, (worldWidth - p.width) * 0.5 - 8)
        return p.x + sin(p.phase * 1.6) * amp
    }

    private func land(on p: Platform) -> Bool {
        let px = movedX(for: p)
        let left = px - p.width * 0.5
        let right = px + p.width * 0.5
        let feet = playerY - playerR
        // platform thickness ~14
        let top = p.y
        let bottom = p.y - 16
        let withinX = playerX + playerR * 0.55 >= left && playerX - playerR * 0.55 <= right
        let crossing = feet <= top && feet >= bottom && playerY >= p.y - playerR
        return withinX && crossing
    }

    private func bounce(on p: inout Platform) {
        switch p.kind {
        case .normal:
            velY = jumpV
            spawnDust(atX: playerX, y: p.y, color: JumpTheme.platform)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .moving:
            velY = jumpV * 1.02
            spawnDust(atX: playerX, y: p.y, color: JumpTheme.platformMoving)
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .spring:
            velY = springV
            spawnDust(atX: playerX, y: p.y, color: JumpTheme.platformSpring)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            flashLanding = true
            Task {
                try? await Task.sleep(nanoseconds: 120_000_000)
                flashLanding = false
            }
        }
        // snap feet to platform top for stability
        playerY = p.y + playerR
    }

    private func spawnDust(atX x: CGFloat, y: CGFloat, color: Color) {
        for _ in 0..<6 {
            particles.append(
                Particle(
                    id: UUID(),
                    x: x + CGFloat.random(in: -10...10),
                    y: y + CGFloat.random(in: -2...6),
                    vx: CGFloat.random(in: -80...80),
                    vy: CGFloat.random(in: 40...140),
                    life: CGFloat.random(in: 0.25...0.5),
                    color: color,
                    size: CGFloat.random(in: 3...6)
                )
            )
        }
        if particles.count > 40 {
            particles.removeFirst(particles.count - 40)
        }
    }

    private func updateParticles(dt: CGFloat) {
        for i in particles.indices {
            particles[i].x += particles[i].vx * dt
            particles[i].y += particles[i].vy * dt
            particles[i].vy -= 400 * dt
            particles[i].life -= dt
        }
        particles.removeAll { $0.life <= 0 }
    }

    private func seedPlatforms() {
        // starter floor
        platforms.append(
            Platform(id: UUID(), x: worldWidth * 0.5, y: 20, width: worldWidth * 0.55, kind: .normal, phase: 0)
        )
        nextPlatformY = 20
        for _ in 0..<14 {
            spawnPlatform()
        }
    }

    private func spawnPlatform() {
        let gap = CGFloat.random(in: 70...115)
        nextPlatformY += gap
        let width = CGFloat.random(in: 68...118)
        let margin = width * 0.5 + 12
        let x = CGFloat.random(in: margin...(worldWidth - margin))
        let roll = Int.random(in: 0...99)
        let kind: PlatformKind
        if nextPlatformY < 300 {
            kind = .normal
        } else if roll < 12 {
            kind = .spring
        } else if roll < 38 {
            kind = .moving
        } else {
            kind = .normal
        }
        platforms.append(
            Platform(
                id: UUID(),
                x: x,
                y: nextPlatformY,
                width: width,
                kind: kind,
                phase: CGFloat.random(in: 0...6)
            )
        )
    }

    private func gameOver() {
        stopLoop()
        phase = .gameOver
        moveInput = 0
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    // expose for rendering helpers
    func screenY(_ worldY: CGFloat) -> CGFloat {
        // world y up -> screen y down
        return (worldHeight - (worldY - cameraY)) 
    }

    func screenX(_ worldX: CGFloat) -> CGFloat { worldX }

    func platformDrawX(_ p: Platform) -> CGFloat { movedX(for: p) }

    var playerRadius: CGFloat { playerR }
}

// CADisplayLink target (avoid retain cycle via weak)
private final class TickTarget: NSObject {
    weak var owner: JumpEngine?
    init(owner: JumpEngine) { self.owner = owner }
    @objc func tick() {
        owner?.step(now: Date())
    }
}

// MARK: - Root View

struct ContentView: View {
    @StateObject private var game = JumpEngine()
    @State private var dragStartX: CGFloat?
    @State private var appearGlow = false

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            ZStack {
                background

                switch game.phase {
                case .menu:
                    menuLayer
                case .playing:
                    playLayer(size: size)
                case .gameOver:
                    ZStack {
                        playLayer(size: size).opacity(0.35).blur(radius: 2)
                        gameOverLayer
                    }
                }
            }
            .onAppear {
                game.configure(size: size)
                withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                    appearGlow = true
                }
            }
            .onChange(of: size) { _, newSize in
                game.configure(size: newSize)
            }
        }
        .preferredColorScheme(.dark)
        .statusBarHidden()
    }

    // MARK: Background

    private var background: some View {
        ZStack {
            LinearGradient(
                colors: [JumpTheme.skyTop, JumpTheme.skyMid, JumpTheme.skyBottom],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // soft orbs
            Circle()
                .fill(JumpTheme.accent.opacity(appearGlow ? 0.16 : 0.08))
                .frame(width: 280, height: 280)
                .blur(radius: 50)
                .offset(x: -110, y: -240)
            Circle()
                .fill(JumpTheme.accent2.opacity(appearGlow ? 0.14 : 0.07))
                .frame(width: 260, height: 260)
                .blur(radius: 55)
                .offset(x: 130, y: 280)

            // subtle stars
            Canvas { ctx, size in
                for i in 0..<28 {
                    let px = CGFloat((i * 73) % 97) / 97 * size.width
                    let py = CGFloat((i * 47) % 89) / 89 * size.height
                    let r = CGFloat(1 + i % 3)
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: px, y: py, width: r, height: r)),
                        with: .color(.white.opacity(0.12 + Double(i % 5) * 0.03))
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }

    // MARK: Menu

    private var menuLayer: some View {
        VStack(spacing: 26) {
            Spacer()

            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [JumpTheme.accent.opacity(0.35), .clear],
                                center: .center,
                                startRadius: 10,
                                endRadius: 70
                            )
                        )
                        .frame(width: 140, height: 140)
                    Image(systemName: "figure.jumprope")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [JumpTheme.accent, JumpTheme.accent2],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: JumpTheme.accent.opacity(0.5), radius: 12)
                }

                Text("跳跳乐")
                    .font(.system(size: 42, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("左右滑动控制 · 踩跳台往上飞")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.62))
            }

            VStack(spacing: 6) {
                Text("最高纪录")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.45))
                Text("\(game.best)")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(JumpTheme.gold)
                    .contentTransition(.numericText())
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 40)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )

            // legend
            HStack(spacing: 14) {
                legendDot(JumpTheme.platform, "普通")
                legendDot(JumpTheme.platformMoving, "移动")
                legendDot(JumpTheme.platformSpring, "弹簧")
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.55))

            Button(action: game.start) {
                Text("开始跳跃")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [JumpTheme.accent, Color.blue.opacity(0.9), JumpTheme.accent2],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .shadow(color: JumpTheme.accent.opacity(0.35), radius: 18, y: 8)
            }
            .padding(.horizontal, 42)

            Spacer()
            Text("左右拖动屏幕转向 · 掉出屏幕就结束")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, 16)
        }
        .padding()
    }

    private func legendDot(_ c: Color, _ t: String) -> some View {
        HStack(spacing: 6) {
            Capsule().fill(c).frame(width: 18, height: 8)
            Text(t)
        }
    }

    // MARK: Play

    private func playLayer(size: CGSize) -> some View {
        ZStack {
            // world
            Canvas { ctx, canvasSize in
                drawWorld(ctx: ctx, size: canvasSize)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let mid = size.width * 0.5
                        // prefer absolute position: left/right of center, smoothed
                        let nx = (value.location.x - mid) / (size.width * 0.42)
                        game.setInput(nx)
                    }
                    .onEnded { _ in
                        game.endDrag()
                    }
            )

            // HUD
            VStack {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("高度")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("\(game.score)")
                            .font(.system(size: 34, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .contentTransition(.numericText())
                            .shadow(color: .black.opacity(0.35), radius: 4, y: 2)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("最佳")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.45))
                        Text("\(game.best)")
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(JumpTheme.gold.opacity(0.95))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)

                Spacer()

                // input hint bar
                if game.phase == .playing {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.left.and.right")
                        Text("按住左右拖动")
                    }
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.bottom, 18)
                }
            }
            .allowsHitTesting(false)

            if game.flashLanding {
                Color.white.opacity(0.08).ignoresSafeArea().allowsHitTesting(false)
            }
        }
    }

    private func drawWorld(ctx: GraphicsContext, size: CGSize) {
        // platforms
        for p in game.platforms {
            let x = game.platformDrawX(p)
            let sy = game.screenY(p.y)
            let rect = CGRect(x: x - p.width * 0.5, y: sy - 7, width: p.width, height: 14)
            let color: Color
            switch p.kind {
            case .normal: color = JumpTheme.platform
            case .moving: color = JumpTheme.platformMoving
            case .spring: color = JumpTheme.platformSpring
            }

            // shadow
            var shadow = Path(roundedRect: rect.offsetBy(dx: 0, dy: 4), cornerRadius: 8)
            ctx.fill(shadow, with: .color(.black.opacity(0.18)))

            var path = Path(roundedRect: rect, cornerRadius: 8)
            ctx.fill(path, with: .color(color.opacity(0.95)))
            // top gloss
            var gloss = Path(roundedRect: CGRect(x: rect.minX + 4, y: rect.minY + 2, width: rect.width - 8, height: 4), cornerRadius: 3)
            ctx.fill(gloss, with: .color(.white.opacity(0.35)))

            if p.kind == .spring {
                // little spring mark
                let midX = rect.midX
                var spring = Path()
                spring.move(to: CGPoint(x: midX - 8, y: rect.minY - 2))
                spring.addLine(to: CGPoint(x: midX - 3, y: rect.minY - 10))
                spring.addLine(to: CGPoint(x: midX + 3, y: rect.minY - 2))
                spring.addLine(to: CGPoint(x: midX + 8, y: rect.minY - 10))
                ctx.stroke(spring, with: .color(color.opacity(0.9)), lineWidth: 2)
            }
        }

        // particles
        for pt in game.particles {
            let sy = game.screenY(pt.y)
            let r = CGRect(x: pt.x - pt.size * 0.5, y: sy - pt.size * 0.5, width: pt.size, height: pt.size)
            ctx.fill(Path(ellipseIn: r), with: .color(pt.color.opacity(Double(max(pt.life, 0)))))
        }

        // player
        let px = game.screenX(game.playerX)
        let py = game.screenY(game.playerY)
        let r = game.playerRadius
        let body = CGRect(x: px - r, y: py - r, width: r * 2, height: r * 2)

        // glow
        ctx.fill(
            Path(ellipseIn: body.insetBy(dx: -8, dy: -8)),
            with: .color(JumpTheme.player.opacity(0.22))
        )
        // body
        ctx.fill(
            Path(ellipseIn: body),
            with: .color(JumpTheme.player)
        )
        // face gloss
        ctx.fill(
            Path(ellipseIn: CGRect(x: px - r * 0.45, y: py - r * 0.55, width: r * 0.7, height: r * 0.45)),
            with: .color(.white.opacity(0.35))
        )
        // eyes
        ctx.fill(Path(ellipseIn: CGRect(x: px - 7, y: py - 4, width: 4.5, height: 5.5)), with: .color(.white))
        ctx.fill(Path(ellipseIn: CGRect(x: px + 2.5, y: py - 4, width: 4.5, height: 5.5)), with: .color(.white))
        ctx.fill(Path(ellipseIn: CGRect(x: px - 5.5, y: py - 2, width: 2.2, height: 2.6)), with: .color(.black.opacity(0.75)))
        ctx.fill(Path(ellipseIn: CGRect(x: px + 4, y: py - 2, width: 2.2, height: 2.6)), with: .color(.black.opacity(0.75)))
    }

    // MARK: Game Over

    private var gameOverLayer: some View {
        VStack(spacing: 20) {
            Text("掉下去了")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                row("本局高度", "\(game.score)", big: true)
                Divider().overlay(Color.white.opacity(0.12))
                row("历史最佳", "\(game.best)", big: false)
            }
            .padding(20)
            .frame(maxWidth: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )

            VStack(spacing: 12) {
                Button(action: game.start) {
                    Text("再跳一次")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: [JumpTheme.player, JumpTheme.accent2], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }
                Button("返回首页", action: game.backToMenu)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white.opacity(0.7))
            }
            .padding(.horizontal, 48)
        }
        .padding()
    }

    private func row(_ t: String, _ v: String, big: Bool) -> some View {
        HStack {
            Text(t).foregroundStyle(.white.opacity(0.55))
            Spacer()
            Text(v)
                .font(.system(size: big ? 34 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(big ? JumpTheme.accent : JumpTheme.gold)
        }
    }
}

#Preview {
    ContentView()
}
