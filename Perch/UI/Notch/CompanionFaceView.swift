import SwiftUI


struct CompanionFaceView: View {
    enum FaceState {
        case idle, talking, listening, happy, excited, concerned, sleepy, thinking

        static func inferred(from text: String, fallback: FaceState = .talking) -> FaceState {
            let lower = text.lowercased()
            if lower.contains("win") || lower.contains("great") || lower.contains("awesome") || lower.contains("proud") || lower.contains("yay") || lower.contains("!") || lower.contains("love") {
                return .happy
            } else if lower.contains("sorry") || lower.contains("tough") || lower.contains("hard") || lower.contains("hug") || lower.contains("tired") || lower.contains("overwork") {
                return .concerned
            } else if lower.contains("think") || lower.contains("maybe") || lower.contains("?") {
                return .thinking
            } else if lower.contains("sleep") || lower.contains("rest") || lower.contains("bed") || lower.contains("wind down") {
                return .sleepy
            }
            return fallback
        }
    }

    var state: FaceState = .idle
    var accent: [Color]
    var size: CGFloat = 40

    @State private var blink = false
    @State private var pulse = false
    @State private var bounceTask: Task<Void, Never>?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                if state == .listening { listeningRings(t: t) }
                orb
                features(t: t)
                if state == .sleepy { snore(t: t) }
            }
            .scaleEffect(x: 1 + breath(t), y: 1 - breath(t))
            .offset(y: bob(t))
            .rotationEffect(.degrees(headTilt))
        }
        .frame(width: size * 1.45, height: size * 1.45)
        .scaleEffect(pulse ? 1.08 : 1)
        .onChange(of: state) { _, _ in bounceOnce() }
        .task { await blinkLoop() }
    }

        // MARK: Orb

    private var orb: some View {
        Circle()
            .fill(LinearGradient(colors: accent, startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay(
                Circle().fill(
                    RadialGradient(
                        colors: [.white.opacity(0.55), .clear],
                        center: .init(x: 0.32, y: 0.24),
                        startRadius: 0,
                        endRadius: size * 0.55
                    )
                )
            )
            .frame(width: size, height: size)
            .shadow(color: accent.first?.opacity(0.55) ?? .clear, radius: size * 0.28)
    }

        // MARK: Features

    private func features(t: TimeInterval) -> some View {
        VStack(spacing: size * 0.09) {
            eyes(t: t)
            mouth(t: t)
        }
        .offset(x: eyeDriftX(t), y: featureOffsetY)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: state)
    }

    private func eyes(t: TimeInterval) -> some View {
        let width: CGFloat = size * (state == .excited ? 0.13 : 0.11)
        let height: CGFloat = blink ? size * 0.05 : eyeOpenHeight
        return HStack(spacing: size * 0.19) {
            Capsule()
                .frame(width: width, height: height)
                .rotationEffect(.degrees(eyeTilt))
            Capsule()
                .frame(width: width, height: height)
                .rotationEffect(.degrees(-eyeTilt))
        }
        .foregroundStyle(.black.opacity(0.72))
    }

    private var eyeOpenHeight: CGFloat {
        switch state {
        case .happy: size * 0.11
        case .excited: size * 0.3
        case .concerned: size * 0.2
        case .sleepy: size * 0.07
        case .thinking: size * 0.16
        default: size * 0.24
        }
    }


    private var eyeTilt: Double {
        state == .concerned ? 16 : 0
    }


    private func eyeDriftX(_ t: TimeInterval) -> CGFloat {
        switch state {
        case .idle: CGFloat(sin(t * 0.5)) * 1.6
        case .thinking: size * 0.07
        default: 0
        }
    }

    private var featureOffsetY: CGFloat {
        switch state {
        case .talking, .happy, .excited: size * 0.05
        case .thinking: -size * 0.04
        default: 0
        }
    }

    @ViewBuilder
    private func mouth(t: TimeInterval) -> some View {
        let dark = Color.black.opacity(0.6)
        switch state {
        case .talking:
            Capsule()
                .fill(dark)
                .frame(width: size * 0.2, height: talkingMouthHeight(t))
        case .happy:
            SmileShape()
                .stroke(dark, style: StrokeStyle(lineWidth: size * 0.06, lineCap: .round))
                .frame(width: size * 0.28, height: size * 0.18)
        case .excited:
            Ellipse()
                .fill(dark)
                .frame(width: size * 0.2, height: size * 0.16)
        case .concerned:
            SmileShape()
                .stroke(dark, style: StrokeStyle(lineWidth: size * 0.045, lineCap: .round))
                .frame(width: size * 0.2, height: size * 0.06)
                .rotationEffect(.degrees(180))
        case .sleepy:
            Circle()
                .fill(dark)
                .frame(width: size * 0.08, height: size * 0.08)
        case .thinking:
            Capsule()
                .fill(dark)
                .frame(width: size * 0.1, height: size * 0.045)
                .offset(x: size * 0.05)
        case .idle, .listening:
            EmptyView()
        }
    }

    private func talkingMouthHeight(_ t: TimeInterval) -> CGFloat {
        let wave = CGFloat(abs(sin(t * 9)))
        return size * 0.05 + size * 0.09 * wave
    }

        // MARK: Ambient motion

    private func bob(_ t: TimeInterval) -> CGFloat {
        let amplitude: CGFloat
        let frequency: Double
        switch state {
        case .excited: amplitude = 2.6; frequency = 3.0
        case .talking: amplitude = 1.6; frequency = 1.9
        case .sleepy: amplitude = 0.9; frequency = 0.7
        case .concerned: amplitude = 0.8; frequency = 1.1
        case .thinking: amplitude = 1.0; frequency = 1.3
        default: amplitude = 1.2; frequency = 1.6
        }
        return CGFloat(sin(t * frequency)) * amplitude
    }

    private func breath(_ t: TimeInterval) -> CGFloat {
        let speed: Double = state == .sleepy ? 1.0 : 1.8
        return CGFloat(sin(t * speed)) * 0.013
    }

    private var headTilt: Double {
        switch state {
        case .listening: 5
        case .thinking: -5
        case .concerned: -3
        case .sleepy: 6
        default: 0
        }
    }

    private func listeningRings(t: TimeInterval) -> some View {
        ForEach(0..<2, id: \.self) { index in
            ring(index: index, t: t)
        }
    }

    private func ring(index: Int, t: TimeInterval) -> some View {
        let opacity: Double = 0.35 - Double(index) * 0.12
        let wave: Double = 0.5 + 0.5 * sin(t * 2.6 + Double(index) * 1.6)
        let scale: CGFloat = 1.08 + 0.14 * CGFloat(wave)
        return Circle()
            .stroke(accent[index % accent.count].opacity(opacity), lineWidth: 1.5)
            .frame(width: size, height: size)
            .scaleEffect(scale)
    }

    private func snore(t: TimeInterval) -> some View {
        let cycle = t.truncatingRemainder(dividingBy: 2.6) / 2.6
        let rise = CGFloat(cycle) * size * 0.3
        return Text("z")
            .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
            .foregroundStyle(.white.opacity(0.65))
            .offset(x: size * 0.52, y: -size * 0.3 - rise)
            .opacity(1 - cycle)
    }

        // MARK: State change and blinking

    private func bounceOnce() {
        bounceTask?.cancel()
        withAnimation(.spring(response: 0.26, dampingFraction: 0.5)) { pulse = true }
        bounceTask = Task {
            try? await Task.sleep(nanoseconds: 170_000_000)
            guard !Task.isCancelled else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.72)) { pulse = false }
        }
    }

    private func blinkLoop() async {
        while !Task.isCancelled {
            let pause = Double.random(in: 2.4...4.6)
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.09)) { blink = true }
            try? await Task.sleep(nanoseconds: 120_000_000)
            withAnimation(.easeIn(duration: 0.12)) { blink = false }
        }
    }
}


struct SmileShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY),
            control: CGPoint(x: rect.midX, y: rect.maxY)
        )
        return path
    }
}
