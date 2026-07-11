import SwiftUI

// MARK: - Models

private struct Bubble: Identifiable, Equatable {
    let id: UUID
    var x: CGFloat          // 0...1 of playfield width
    var y: CGFloat          // 0...1 of playfield height
    var size: CGFloat
    var hue: Double
    var bornAt: Date
    var lifetime: TimeInterval
    var points: Int
}

private enum GamePhase: Equatable {
    case menu
    case playing
    case gameOver
}

// MARK: - ViewModel

@MainActor
private final class BubbleGameModel: ObservableObject {
    @Published var phase: GamePhase = .menu
    @Published var score = 0
    @Published var combo = 0
    @Published var lives = 3
    @Published var bubbles: [Bubble] = []
    @Published var bestScore: Int
    @Published var lastPopPoints: Int = 0
    @Published var showPlus = false

    private var spawnTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var popCount = 0
    private let bestKey = "helloios.bubble.best"

    init() {
        bestScore = UserDefaults.standard.integer(forKey: bestKey)
    }

    func start() {
        spawnTask?.cancel()
        tickTask?.cancel()
        score = 0
        combo = 0
        lives = 3
        bubbles = []
        popCount = 0
        lastPopPoints = 0
        showPlus = false
        phase = .playing
        spawnTask = Task { await spawnLoop() }
        tickTask = Task { await tickLoop() }
    }

    func backToMenu() {
        spawnTask?.cancel()
        tickTask?.cancel()
        bubbles = []
        phase = .menu
    }

    func pop(_ id: UUID) {
        guard phase == .playing else { return }
        guard let idx = bubbles.firstIndex(where: { $0.id == id }) else { return }
        let bubble = bubbles.remove(at: idx)
        popCount += 1
        combo += 1
        let multiplier = min(1 + combo / 3, 8)
        let gained = bubble.points * multiplier
        score += gained
        lastPopPoints = gained
        showPlus = true
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            if !Task.isCancelled { showPlus = false }
        }
        if score > bestScore {
            bestScore = score
            UserDefaults.standard.set(bestScore, forKey: bestKey)
        }
    }

    private func missOne() {
        guard phase == .playing else { return }
        lives -= 1
        combo = 0
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
        if lives <= 0 {
            endGame()
        }
    }

    private func endGame() {
        spawnTask?.cancel()
        tickTask?.cancel()
        bubbles = []
        phase = .gameOver
        UINotificationFeedbackGenerator().notificationOccurred(.error)
    }

    private func spawnLoop() async {
        // difficulty ramps with score
        while !Task.isCancelled && phase == .playing {
            spawnBubble()
            let base: UInt64 = score < 50 ? 700 : score < 150 ? 520 : score < 300 ? 380 : 280
            let jitter = UInt64.random(in: 0...120)
            try? await Task.sleep(nanoseconds: (base + jitter) * 1_000_000)
            // soft cap on simultaneous bubbles
            if bubbles.count > 10 {
                try? await Task.sleep(nanoseconds: 200_000_000)
            }
        }
    }

    private func tickLoop() async {
        while !Task.isCancelled && phase == .playing {
            try? await Task.sleep(nanoseconds: 50_000_000)
            let now = Date()
            let before = bubbles.count
            bubbles.removeAll { now.timeIntervalSince($0.bornAt) >= $0.lifetime }
            let expired = before - bubbles.count
            if expired > 0 {
                for _ in 0..<expired { missOne() }
                if phase != .playing { break }
            }
        }
    }

    private func spawnBubble() {
        let size = CGFloat.random(in: 52...88)
        let lifetime = Double.random(in: 1.6...2.8) - min(Double(score) * 0.002, 0.7)
        let points = size < 60 ? 3 : size < 75 ? 2 : 1
        let b = Bubble(
            id: UUID(),
            x: CGFloat.random(in: 0.12...0.88),
            y: CGFloat.random(in: 0.14...0.86),
            size: size,
            hue: Double.random(in: 0...1),
            bornAt: Date(),
            lifetime: max(lifetime, 0.9),
            points: points
        )
        bubbles.append(b)
    }
}

// MARK: - Root

struct ContentView: View {
    @StateObject private var game = BubbleGameModel()

    var body: some View {
        ZStack {
            background

            switch game.phase {
            case .menu:
                menuLayer
            case .playing:
                playLayer
            case .gameOver:
                gameOverLayer
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: Background

    private var background: some View {
        LinearGradient(
            colors: [
                Color(red: 0.07, green: 0.08, blue: 0.16),
                Color(red: 0.12, green: 0.06, blue: 0.22),
                Color(red: 0.04, green: 0.10, blue: 0.18)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
        .overlay {
            // soft glows
            Circle()
                .fill(Color.purple.opacity(0.18))
                .frame(width: 280, height: 280)
                .blur(radius: 60)
                .offset(x: -120, y: -220)
            Circle()
                .fill(Color.cyan.opacity(0.12))
                .frame(width: 260, height: 260)
                .blur(radius: 50)
                .offset(x: 140, y: 260)
        }
    }

    // MARK: Menu

    private var menuLayer: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 10) {
                Image(systemName: "circle.grid.cross.fill")
                    .font(.system(size: 54, weight: .semibold))
                    .foregroundStyle(
                        LinearGradient(colors: [.cyan, .purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .symbolEffect(.pulse, options: .repeating)

                Text("泡泡冲刺")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("点掉泡泡 · 连击加倍 · 别让它们溜走")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.65))
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
                Text("最高分")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(game.bestScore)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }
            .padding(.vertical, 18)
            .padding(.horizontal, 36)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))

            Button(action: game.start) {
                Text("开始游戏")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(colors: [.cyan, .blue, .purple], startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
                    .foregroundStyle(.white)
                    .shadow(color: .cyan.opacity(0.35), radius: 16, y: 6)
            }
            .padding(.horizontal, 40)

            Spacer()
            Text("HelloiOS · 本地签名真机版")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.35))
                .padding(.bottom, 12)
        }
        .padding()
    }

    // MARK: Play

    private var playLayer: some View {
        GeometryReader { geo in
            let topBar: CGFloat = 96
            let playHeight = max(geo.size.height - topBar - 24, 200)
            let playSize = CGSize(width: geo.size.width, height: playHeight)

            VStack(spacing: 0) {
                hud
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .frame(height: topBar)

                ZStack {
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 28, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )

                    ForEach(game.bubbles) { bubble in
                        BubbleView(bubble: bubble) {
                            game.pop(bubble.id)
                        }
                        .position(
                            x: bubble.x * playSize.width,
                            y: bubble.y * playSize.height
                        )
                        .transition(.scale.combined(with: .opacity))
                    }

                    if game.showPlus {
                        Text("+\(game.lastPopPoints)")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                            .foregroundStyle(.yellow)
                            .shadow(color: .orange.opacity(0.6), radius: 8)
                            .transition(.scale.combined(with: .opacity))
                            .allowsHitTesting(false)
                    }
                }
                .frame(width: playSize.width - 24, height: playSize.height)
                .animation(.spring(response: 0.28, dampingFraction: 0.72), value: game.bubbles)
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
    }

    private var hud: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("得分")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(game.score)")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
            }

            Spacer()

            if game.combo >= 2 {
                Text("连击 ×\(min(1 + game.combo / 3, 8))")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange.opacity(0.25)))
                    .foregroundStyle(.orange)
                    .transition(.scale)
            }

            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Image(systemName: i < game.lives ? "heart.fill" : "heart")
                        .foregroundStyle(i < game.lives ? Color.pink : Color.white.opacity(0.25))
                        .font(.title3)
                }
            }
        }
        .animation(.easeOut(duration: 0.15), value: game.combo)
        .animation(.easeOut(duration: 0.15), value: game.lives)
    }

    // MARK: Game Over

    private var gameOverLayer: some View {
        VStack(spacing: 22) {
            Spacer()

            Text("游戏结束")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            VStack(spacing: 10) {
                scoreRow(title: "本局得分", value: "\(game.score)", emphasize: true)
                scoreRow(title: "历史最高", value: "\(game.bestScore)", emphasize: false)
            }
            .padding(20)
            .frame(maxWidth: 300)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))

            VStack(spacing: 12) {
                Button(action: game.start) {
                    Text("再来一局")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 15)
                        .background(
                            LinearGradient(colors: [.pink, .purple], startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                        .foregroundStyle(.white)
                }

                Button(action: game.backToMenu) {
                    Text("返回首页")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.vertical, 8)
                }
            }
            .padding(.horizontal, 48)

            Spacer()
        }
        .padding()
    }

    private func scoreRow(title: String, value: String, emphasize: Bool) -> some View {
        HStack {
            Text(title)
                .foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value)
                .font(.system(size: emphasize ? 32 : 22, weight: .bold, design: .rounded))
                .foregroundStyle(emphasize ? Color.cyan : Color.white)
        }
    }
}

// MARK: - Bubble View

private struct BubbleView: View {
    let bubble: Bubble
    let onTap: () -> Void

    @State private var appear = false
    @State private var now = Date()

    private let timer = Timer.publish(every: 0.05, on: .main, in: .common).autoconnect()

    var body: some View {
        let remaining = max(0, bubble.lifetime - now.timeIntervalSince(bubble.bornAt))
        let progress = remaining / bubble.lifetime

        Button(action: onTap) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hue: bubble.hue, saturation: 0.55, brightness: 1.0).opacity(0.95),
                                Color(hue: bubble.hue, saturation: 0.85, brightness: 0.55).opacity(0.75)
                            ],
                            center: .topLeading,
                            startRadius: 2,
                            endRadius: bubble.size * 0.7
                        )
                    )
                    .overlay {
                        Circle()
                            .stroke(Color.white.opacity(0.35), lineWidth: 1.5)
                    }
                    .overlay(alignment: .topLeading) {
                        Circle()
                            .fill(Color.white.opacity(0.45))
                            .frame(width: bubble.size * 0.22, height: bubble.size * 0.22)
                            .offset(x: bubble.size * 0.18, y: bubble.size * 0.16)
                            .blur(radius: 0.5)
                    }
                    .shadow(color: Color(hue: bubble.hue, saturation: 0.8, brightness: 1).opacity(0.45), radius: 10)

                // lifetime ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.white.opacity(0.55), style: StrokeStyle(lineWidth: 3, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .padding(3)
            }
            .frame(width: bubble.size, height: bubble.size)
            .scaleEffect(appear ? 1 : 0.2)
            .opacity(appear ? (0.55 + 0.45 * progress) : 0)
        }
        .buttonStyle(.plain)
        .onAppear {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.65)) {
                appear = true
            }
        }
        .onReceive(timer) { value in
            now = value
        }
    }
}

#Preview {
    ContentView()
}
