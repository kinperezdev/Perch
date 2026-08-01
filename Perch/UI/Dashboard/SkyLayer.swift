import SwiftUI

/// Sits in the top portion of the Dashboard background. Shows twinkling stars
/// and an occasional shooting star at night, drifting clouds and birds by day,
/// or falling rain (with a lightning flash for thunderstorms) when that's what
/// the real local weather is doing, via `SkyService`.
struct SkyLayer: View {
    let isNight: Bool
    let condition: SkyCondition

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                ZStack(alignment: .topLeading) {
                    switch condition {
                    case .thunderstorm:
                        rainLayer(t: t, intensity: 1.0, size: geo.size)
                        lightningFlash(t: t)
                    case .rain:
                        rainLayer(t: t, intensity: 0.7, size: geo.size)
                    case .clear:
                        if isNight {
                            starsLayer(t: t, size: geo.size)
                        } else {
                            dayLayer(t: t, size: geo.size)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .clipped()
    }

        // MARK: Stars (night)

    private static let starSeeds: [(x: Double, y: Double, size: Double, speed: Double, phase: Double)] = (0..<28).map { _ in
        (
            x: Double.random(in: 0...1),
            y: Double.random(in: 0...0.55),
            size: Double.random(in: 1...2.4),
            speed: Double.random(in: 0.4...1.1),
            phase: Double.random(in: 0...6.28)
        )
    }

    private func starsLayer(t: TimeInterval, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(Self.starSeeds.enumerated()), id: \.offset) { _, star in
                Circle()
                    .fill(.white)
                    .frame(width: star.size, height: star.size)
                    .opacity(0.35 + 0.5 * (0.5 + 0.5 * sin(t * star.speed + star.phase)))
                    .position(x: driftedX(star: star, t: t, width: size.width), y: star.y * size.height)
            }
            shootingStar(t: t, size: size)
        }
    }

    /// Stars drift slowly to the left, wrapping back around once they pass
    /// the edge, so the night sky feels like it's gently moving rather than
    /// just twinkling in place.
    private func driftedX(star: (x: Double, y: Double, size: Double, speed: Double, phase: Double), t: TimeInterval, width: CGFloat) -> CGFloat {
        guard width > 0 else { return star.x * width }
        let driftSpeed: CGFloat = 2.2
        let raw = (star.x * width - CGFloat(t) * driftSpeed).truncatingRemainder(dividingBy: width)
        return raw < 0 ? raw + width : raw
    }

    /// A tiny deterministic RNG seeded per shooting-star cycle, so each star
    /// gets a different path but stays consistent for the length of its own
    /// streak instead of jittering frame to frame. SplitMix64, chosen because
    /// (unlike xorshift) it decorrelates well even for sequential seeds like
    /// 1, 2, 3... which is exactly what an incrementing cycle index is.
    private struct SeededGenerator: RandomNumberGenerator {
        private var state: UInt64
        init(seed: Int) { state = UInt64(bitPattern: Int64(seed)) }
        mutating func next() -> UInt64 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }

    private func shootingStar(t: TimeInterval, size: CGSize) -> some View {
        let cycle = 11.0
        let cycleIndex = Int(t / cycle)
        let progress = t.truncatingRemainder(dividingBy: cycle) / cycle
        let active = progress < 0.18
        let localProgress = progress / 0.18

        var rng = SeededGenerator(seed: cycleIndex)
        let startX = size.width * CGFloat.random(in: 0.05...0.75, using: &rng)
        let startY = size.height * CGFloat.random(in: 0.02...0.3, using: &rng)
        let travelX = size.width * CGFloat.random(in: 0.2...0.4, using: &rng)
        let travelY = size.height * CGFloat.random(in: 0.15...0.4, using: &rng)
        let endX = startX + travelX
        let endY = startY + travelY

        let x = startX + (endX - startX) * localProgress
        let y = startY + (endY - startY) * localProgress
        let angle = atan2(Double(travelY), Double(travelX)) * 180 / .pi
        return Capsule()
            .fill(LinearGradient(colors: [.white.opacity(0), .white.opacity(0.9)], startPoint: .leading, endPoint: .trailing))
            .frame(width: 46, height: 2)
            .rotationEffect(.degrees(angle))
            .position(x: x, y: y)
            .opacity(active ? (1 - localProgress) * 0.95 : 0)
    }

        // MARK: Day (clouds + birds)

    private static let cloudSeeds: [(y: Double, size: CGFloat, speed: Double, offset: Double)] = [
        (y: 0.10, size: 70, speed: 0.006, offset: 0.0),
        (y: 0.24, size: 50, speed: 0.009, offset: 0.4),
        (y: 0.05, size: 42, speed: 0.011, offset: 0.75),
    ]

    private func dayLayer(t: TimeInterval, size: CGSize) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(Self.cloudSeeds.enumerated()), id: \.offset) { _, cloud in
                cloudShape(size: cloud.size)
                    .position(x: driftX(t: t, speed: cloud.speed, offset: cloud.offset, width: size.width), y: cloud.y * size.height)
            }
            bird(t: t, delay: 0, y: 0.16, size: size)
            bird(t: t, delay: 9, y: 0.3, size: size)
        }
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .white, location: 0.4),
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }

    /// Keeps clouds gently swaying within the right side of the sky instead of
    /// sweeping across the whole width.
    private func driftX(t: TimeInterval, speed: Double, offset: Double, width: CGFloat) -> CGFloat {
        let bandStart = width * 0.55
        let bandWidth = width * 0.4
        let sway = 0.5 + 0.5 * sin(t * speed * 6.0 + offset * 6.28)
        return bandStart + CGFloat(sway) * bandWidth
    }

    private func cloudShape(size: CGFloat) -> some View {
        ZStack {
            Circle().frame(width: size * 0.6, height: size * 0.6).offset(x: -size * 0.25)
            Circle().frame(width: size * 0.8, height: size * 0.8)
            Circle().frame(width: size * 0.55, height: size * 0.55).offset(x: size * 0.35, y: size * 0.05)
        }
        .foregroundStyle(.white)
        .compositingGroup()
        .opacity(0.14)
        .blur(radius: 1.5)
    }

    /// Each bird only flies for the first `flightPortion` of its cycle, then
    /// rests off-screen for the remainder, so there's a real gap between
    /// flights instead of a continuous stream of birds.
    private func bird(t: TimeInterval, delay: Double, y: Double, size: CGSize) -> some View {
        let cycle = 18.0
        let flightPortion = 0.35
        let rawProgress = (t + delay).truncatingRemainder(dividingBy: cycle) / cycle
        guard rawProgress < flightPortion else { return AnyView(EmptyView()) }
        let progress = rawProgress / flightPortion
        let x = CGFloat(progress) * (size.width + 80) - 40
        let flap = sin(t * 10)
        return AnyView(
            BirdShape()
                .stroke(.white.opacity(0.5), style: StrokeStyle(lineWidth: 1.3, lineCap: .round))
                .frame(width: 11, height: 4 + CGFloat(flap) * 2)
                .position(x: x, y: y * size.height)
        )
    }

        // MARK: Rain / thunder

    private static let dropSeeds: [(x: Double, delay: Double, speed: Double)] = (0..<40).map { _ in
        (
            x: Double.random(in: 0...1),
            delay: Double.random(in: 0...1),
            speed: Double.random(in: 0.7...1.1)
        )
    }

    private func rainLayer(t: TimeInterval, intensity: Double, size: CGSize) -> some View {
        let activeCount = Int(Double(Self.dropSeeds.count) * intensity)
        return ZStack(alignment: .topLeading) {
            ForEach(Array(Self.dropSeeds.prefix(activeCount).enumerated()), id: \.offset) { _, drop in
                raindrop(t: t, drop: drop, size: size)
            }
        }
    }

    private func raindrop(t: TimeInterval, drop: (x: Double, delay: Double, speed: Double), size: CGSize) -> some View {
        let cycle = 0.9 / drop.speed
        let progress = (t + drop.delay).truncatingRemainder(dividingBy: cycle) / cycle
        let y = progress * (size.height * 0.6)
        return Capsule()
            .fill(.white.opacity(0.28))
            .frame(width: 1.2, height: 12)
            .position(x: drop.x * size.width, y: y)
            .opacity(1 - progress * 0.4)
    }

    private func lightningFlash(t: TimeInterval) -> some View {
        let cycle = 22.0
        let progress = t.truncatingRemainder(dividingBy: cycle)
        let flashOpacity: Double = progress < 0.12 ? 0.5 : (progress > 0.2 && progress < 0.28 ? 0.25 : 0)
        return Rectangle()
            .fill(.white)
            .opacity(flashOpacity)
    }
}

struct BirdShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.width * 0.25, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.width * 0.75, y: rect.minY))
        return path
    }
}
