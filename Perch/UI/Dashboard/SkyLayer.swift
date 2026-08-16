import SwiftUI

/// A soft color glow anchored to the top edge, fading to nothing partway down
/// so the base background stays a constant dark near-black everywhere else,
/// the same "colored light hitting the top of a dark surface" look used
/// across Dashboard, Settings, the menu bar, and the notch.
struct SkyTintOverlay: View {
    let tint: Color
    var height: CGFloat = 240

    var body: some View {
        LinearGradient(
            colors: [tint.opacity(0.4), tint.opacity(0.12), .clear],
            startPoint: .top,
            endPoint: .bottom
        )
        .frame(height: height)
        .allowsHitTesting(false)
    }
}

/// Sits in the top portion of the Dashboard background. Always the same
/// black night sky with twinkling stars and an occasional shooting star,
/// everywhere it's used, so the look is consistent instead of shifting
/// with the time of day or local weather.
struct SkyLayer: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                starsLayer(t: t, size: geo.size)
            }
        }
        .allowsHitTesting(false)
        .clipped()
    }

        // MARK: Stars

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
}
