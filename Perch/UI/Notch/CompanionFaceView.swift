import SwiftUI

struct CompanionFaceView: View {
    enum FaceState {
        case idle, talking, listening, happy, excited, concerned, sleepy, thinking, playing

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
    var showsMouth: Bool = true
    var personality: Personality? = nil
    var lookBias: CGSize? = nil
    var glows: Bool = true

    @State private var blink = false
    @State private var pulse = false
    @State private var bounceTask: Task<Void, Never>?
    @State private var faceCenter: CGPoint?

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                if state == .listening { listeningRings(t: t) }
                orb
                if state == .playing { headphones }
                personalityAccessory(t: t)
                features(t: t)
                if state == .sleepy { snore(t: t) }
                if state == .playing { musicNotes(t: t) }
            }
            .scaleEffect(x: 1 + breath(t), y: 1 - breath(t))
            .offset(y: bob(t))
            .rotationEffect(.degrees(headTilt(t: t)))
        }
        .frame(width: size * 1.45, height: size * 1.45)
        .scaleEffect(pulse ? 1.08 : 1)
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onChange(of: proxy.frame(in: .global)) { _, frame in
                        faceCenter = CGPoint(x: frame.midX, y: frame.midY)
                    }
                    .onAppear {
                        let frame = proxy.frame(in: .global)
                        faceCenter = CGPoint(x: frame.midX, y: frame.midY)
                    }
            }
        )
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
            .shadow(color: glows ? (accent.first?.opacity(0.55) ?? .clear) : .clear, radius: size * 0.28)
    }

        // MARK: Features

    private func features(t: TimeInterval) -> some View {
        let look = lookOffset(t: t)
        return VStack(spacing: size * 0.09) {
            eyes(t: t)
            if showsMouth { mouth(t: t) }
        }
        .offset(x: look.width, y: featureOffsetY + look.height)
        .animation(.spring(response: 0.32, dampingFraction: 0.72), value: state)
    }

    /// Where the eyes should shift to look toward the cursor, in this window.
    /// Falls back to the original idle drift when the cursor is outside the
    /// window or this face hasn't reported its position yet.
    private func lookOffset(t: TimeInterval) -> CGSize {
        if let lookBias { return lookBias }
        guard let cursor = CursorTracker.shared.location, let center = faceCenter else {
            return CGSize(width: eyeDriftX(t), height: 0)
        }
        let dx = cursor.x - center.x
        let dy = cursor.y - center.y
        let distance = max(sqrt(dx * dx + dy * dy), 1)
        let maxShift = size * 0.09
        let reach: CGFloat = 220
        let factor = min(distance, reach) / reach
        return CGSize(width: (dx / distance) * maxShift * factor, height: (dy / distance) * maxShift * 0.6 * factor)
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
        case .sleepy: size * 0.07 + size * 0.13 * CGFloat(cursorCloseness())
        case .thinking: size * 0.16
        default: size * 0.24
        }
    }

    /// 1 when the cursor is right next to the face, fading to 0 by `reach` away.
    /// Lets a sleepy Perch gradually peek open as the cursor gets close, instead
    /// of snapping between fully shut and fully open.
    private func cursorCloseness() -> Double {
        guard let cursor = CursorTracker.shared.location, let center = faceCenter else { return 0 }
        let dx = cursor.x - center.x
        let dy = cursor.y - center.y
        let distance = sqrt(dx * dx + dy * dy)
        let reach: CGFloat = 160
        return Double(1 - min(distance, reach) / reach)
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
        case .idle, .listening, .playing:
            EmptyView()
        }
    }

    private func talkingMouthHeight(_ t: TimeInterval) -> CGFloat {
        let wave = CGFloat(abs(sin(t * 9)))
        return size * 0.05 + size * 0.09 * wave
    }

    private var headphones: some View {
        ZStack {
            Path { path in
                let w = size * 1.15
                let h = size * 0.6
                path.addArc(
                    center: CGPoint(x: w/2, y: h),
                    radius: w/2,
                    startAngle: .degrees(180),
                    endAngle: .degrees(0),
                    clockwise: false
                )
            }
            .stroke(Color.white.opacity(0.8), style: StrokeStyle(lineWidth: size * 0.08, lineCap: .round))
            .frame(width: size * 1.15, height: size * 0.6)
            .offset(y: -size * 0.15)
            
            HStack(spacing: size * 0.82) {
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: size * 0.18, height: size * 0.45)
                Capsule()
                    .fill(Color.white.opacity(0.95))
                    .frame(width: size * 0.18, height: size * 0.45)
            }
            .offset(y: size * 0.05)
        }
    }

        // MARK: Personality accessories

    @ViewBuilder
    private func personalityAccessory(t: TimeInterval) -> some View {
        switch personality {
        case .mother: motherAccessory
        case .homie: homieAccessory
        case .professional: professionalAccessory
        case .mentor: mentorAccessory(t: t)
        case .coach: coachAccessory
        case .playful: playfulAccessory
        case nil: EmptyView()
        }
    }

    /// A flower clip tucked above one ear.
    private var motherAccessory: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Ellipse()
                    .fill(Color(hex: 0xFF6F91))
                    .frame(width: size * 0.13, height: size * 0.2)
                    .offset(y: -size * 0.1)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle()
                .fill(Color.yellow)
                .frame(width: size * 0.11, height: size * 0.11)
        }
        .offset(x: size * 0.34, y: -size * 0.36)
    }

    /// A flat-brim cap tilted over the crown, homie's snapback.
    private var homieAccessory: some View {
        let capWidth = size * 0.96
        let capHeight = size * 0.5
        return ZStack(alignment: .topLeading) {
            UnevenRoundedRectangle(
                topLeadingRadius: capHeight,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: capHeight,
                style: .continuous
            )
            .fill(Color(hex: 0x2B2B30))
            .frame(width: capWidth, height: capHeight)
            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: size * 0.055, height: size * 0.055)
                .offset(x: capWidth * 0.5 - size * 0.0275, y: -size * 0.015)
            Capsule()
                .fill(Color(hex: 0x1C1C1F))
                .frame(width: capWidth * 0.38, height: size * 0.09)
                .offset(x: capWidth * 0.9, y: capHeight - size * 0.03)
        }
        .rotationEffect(.degrees(0))
        .offset(x: size * 0.01, y: -size * 0.45)
    }

    /// A necktie knotted just below the chin.
    private var professionalAccessory: some View {
        VStack(spacing: -size * 0.01) {
            Capsule()
                .fill(Color(hex: 0x8E1A1A))
                .frame(width: size * 0.11, height: size * 0.07)
            NecktieShape()
                .fill(Color(hex: 0xC22B2B))
                .frame(width: size * 0.16, height: size * 0.24)
        }
        .offset(y: size * 0.56)
    }

    /// Round wire glasses resting over the eyes, tracking the same look
    /// direction as the eyes instead of sitting fixed in place.
    private func mentorAccessory(t: TimeInterval) -> some View {
        let look = lookOffset(t: t)
        let lensSize = size * 0.24 + eyeOpenHeight * 0.3
        // Smaller eyes (sleepy, blinking) sit higher on the face, so lift the
        // glasses to match instead of letting them sag toward the mouth.
        let smallEyesLift = max(size * 0.24 - eyeOpenHeight, 0) * 0.6
        return HStack(spacing: size * 0.05) {
            Circle().stroke(Color.black.opacity(0.85), lineWidth: size * 0.028)
                .frame(width: lensSize, height: lensSize)
            Circle().stroke(Color.black.opacity(0.85), lineWidth: size * 0.028)
                .frame(width: lensSize, height: lensSize)
        }
        .overlay(
            Capsule()
                .fill(Color.black.opacity(0.85))
                .frame(width: size * 0.08, height: size * 0.022)
        )
        .offset(x: look.width, y: featureOffsetY + look.height - smallEyesLift)
    }

    /// A whistle on a cord around the neck.
    private var coachAccessory: some View {
        VStack(spacing: -size * 0.02) {
            HStack(spacing: size * 0.08) {
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: size * 0.02, height: size * 0.2)
                    .rotationEffect(.degrees(-28))
                Capsule()
                    .fill(Color.white.opacity(0.6))
                    .frame(width: size * 0.02, height: size * 0.2)
                    .rotationEffect(.degrees(28))
            }
            ZStack {
                Circle()
                    .fill(Color(hex: 0xC7CCD1))
                    .frame(width: size * 0.16, height: size * 0.16)
                Capsule()
                    .fill(Color.white.opacity(0.9))
                    .frame(width: size * 0.06, height: size * 0.022)
            }
        }
        .offset(y: size * 0.5)
    }

    /// A bouncy antenna with a little ball on top, playful's spark.
    private var playfulAccessory: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(Color(hex: 0xFFD23D))
                .frame(width: size * 0.12, height: size * 0.12)
            Capsule()
                .fill(Color.white.opacity(0.5))
                .frame(width: size * 0.018, height: size * 0.22)
        }
        .offset(x: size * 0.14, y: -size * 0.58)
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
        case .playing: amplitude = 3.0; frequency = 4.2
        default: amplitude = 1.2; frequency = 1.6
        }
        return CGFloat(sin(t * frequency)) * amplitude
    }

    private func breath(_ t: TimeInterval) -> CGFloat {
        let speed: Double = state == .sleepy ? 1.0 : 1.8
        return CGFloat(sin(t * speed)) * 0.013
    }

    private func headTilt(t: TimeInterval) -> Double {
        switch state {
        case .listening: return 5
        case .thinking: return -5
        case .concerned: return -3
        case .sleepy: return 6
        case .playing: return sin(t * 3.0) * 12
        default: return 0
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

    private func musicNotes(t: TimeInterval) -> some View {
        let cycle = t.truncatingRemainder(dividingBy: 1.8) / 1.8
        let rise = CGFloat(cycle) * size * 0.5
        let sway = CGFloat(sin(t * 6)) * size * 0.1
        return Image(systemName: "music.note")
            .font(.system(size: size * 0.3, weight: .bold))
            .foregroundStyle(.white.opacity(0.8))
            .offset(x: size * 0.55 + sway, y: -size * 0.2 - rise)
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
            let pause = state == .playing ? Double.random(in: 1.2...2.5) : Double.random(in: 2.4...4.6)
            try? await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.09)) { blink = true }
            let closedDuration: UInt64 = state == .playing ? 600_000_000 : 120_000_000
            try? await Task.sleep(nanoseconds: closedDuration)
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

/// A tapering necktie: wide at the knot, narrowing to a point at the tip.
struct NecktieShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX + rect.width * 0.18, y: rect.maxY * 0.75))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX - rect.width * 0.18, y: rect.maxY * 0.75))
        path.closeSubpath()
        return path
    }
}
