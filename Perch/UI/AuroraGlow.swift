import SwiftUI

/// Slow-flowing ambient glow anchored to the bottom edge, tinted with the active
/// personality's two accent colors. Each band drifts independently (different
/// speed and phase) so it reads as organic aurora motion rather than a synced pulse.
struct AuroraGlow: View {
    let accent: [Color]

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(accent[0].opacity(0.36 + 0.05 * sin(t * 0.35)))
                    .frame(width: 340, height: 170)
                    .blur(radius: 75)
                    .offset(x: -90 + sin(t * 0.22) * 45, y: 70 + cos(t * 0.17) * 18)
                Ellipse()
                    .fill(accent[1].opacity(0.32 + 0.05 * sin(t * 0.28 + 2)))
                    .frame(width: 320, height: 160)
                    .blur(radius: 75)
                    .offset(x: 110 + sin(t * 0.19 + 2) * 50, y: 80 + cos(t * 0.24 + 1) * 16)
                LinearGradient(
                    colors: [accent[0].opacity(0.16 + 0.05 * sin(t * 0.3)), .clear],
                    startPoint: .bottom,
                    endPoint: .top
                )
                .frame(height: 220)
            }
        }
        .allowsHitTesting(false)
    }
}
