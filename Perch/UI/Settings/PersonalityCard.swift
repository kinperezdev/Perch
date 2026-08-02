import SwiftUI

struct PersonalityCard: View {
    let personality: Personality
    let isSelected: Bool
    let isLocked: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    CompanionFaceView(state: isSelected ? .excited : .idle, accent: personality.accentColors, size: 24, personality: personality)
                    Spacer()
                    if isLocked {
                        ProTag()
                    } else if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(personality.accentColors[0])
                    }
                }
                Text(personality.displayName)
                    .font(.perchRounded(13, weight: .semibold))
                Text(personality.tagline)
                    .font(.perchRounded(10))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                Text("\"\(MessageLibrary.sample(personality: personality))\"")
                    .font(.system(size: 9.5, design: .rounded))
                    .italic()
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 152, alignment: .topLeading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(hex: 0x121216))
                    SkyTintOverlay(tint: personality.accentColors[0], height: 92)
                        .opacity(isSelected ? 1 : 0.65)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    PersonalityScene(personality: personality, isSelected: isSelected)
                        .frame(height: 36)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? personality.accentColors[0].opacity(0.6) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}

/// The ground of each personality card is its own little place, not just a
/// tinted hill: a grass field with flowers for Mom, a court for Homie, a
/// skyline for the Assistant, mountains with a leaf for Mentor, a track for
/// Coach, a starfield for Spark. Kept deliberately quiet (low opacity, one
/// small accent at most) so it reads as scenery behind the text, not another
/// row of icons competing with it.
private struct PersonalityScene: View {
    let personality: Personality
    let isSelected: Bool

    private var accent: [Color] { personality.accentColors }
    private var tint: Color { personality.groundColor }
    private var opacity: Double { isSelected ? 0.4 : 0.26 }
    private var lineOpacity: Double { isSelected ? 0.3 : 0.18 }

    var body: some View {
        switch personality {
        case .mother:
            ZStack(alignment: .bottom) {
                GroundShape().fill(tint.opacity(opacity))
                flower(size: 16).offset(x: 8)
            }
        case .mentor:
            ZStack(alignment: .bottom) {
                MountainShape(peaks: 3).fill(tint.opacity(opacity))
                Image(systemName: "leaf.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(accent[0].opacity(lineOpacity + 0.1))
                    .offset(x: 10, y: -6)
            }
        case .homie:
            ZStack(alignment: .bottom) {
                Rectangle().fill(tint.opacity(opacity))
                courtLines
            }
        case .professional:
            SkylineShape()
                .fill(tint.opacity(opacity))
        case .coach:
            ZStack(alignment: .bottom) {
                GroundShape().fill(tint.opacity(opacity))
                trackLines
            }
        case .playful:
            ZStack(alignment: .bottom) {
                GroundShape().fill(tint.opacity(opacity))
                starScatter
            }
        }
    }

    private func flower(size: CGFloat) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(accent[0].opacity(0.4))
                    .frame(width: size * 0.34, height: size * 0.62)
                    .offset(y: -size * 0.31)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle()
                .fill(accent[1].opacity(0.5))
                .frame(width: size * 0.26, height: size * 0.26)
        }
        .frame(width: size, height: size)
    }

    private var courtLines: some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(lineOpacity))
                .frame(height: 1)
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(.white.opacity(lineOpacity), lineWidth: 1)
                .frame(width: 26, height: 26)
                .offset(y: -10)
        }
    }

    private var trackLines: some View {
        Capsule()
            .stroke(.white.opacity(lineOpacity), lineWidth: 1)
            .frame(width: 80, height: 18)
            .offset(y: 6)
    }

    private var starScatter: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 5 + CGFloat(i) * 2))
                    .foregroundStyle(.white.opacity(lineOpacity))
                    .offset(x: CGFloat(-16 + i * 14), y: CGFloat(-2 - i * 3))
            }
        }
    }
}

/// A gentle rising hill silhouette anchored to the bottom edge, giving each
/// card a sense of ground/land for its motif to sit on instead of floating
/// on a flat color field. Also the degenerate (single-peak) case of
/// `MountainShape`, which delegates here rather than duplicating the path.
private struct GroundShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - rect.height * 0.22))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.maxY - rect.height * 0.7),
            control: CGPoint(x: rect.maxX * 0.62, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// Overlapping triangular peaks anchored to the bottom edge: one low rise
/// for Mom's grassy field (via `GroundShape`), three for Mentor's mountains.
private struct MountainShape: Shape {
    var peaks: Int = 1

    func path(in rect: CGRect) -> Path {
        guard peaks > 1 else { return GroundShape().path(in: rect) }
        let heights: [CGFloat] = [0.55, 0.95, 0.7]
        let width = rect.width / CGFloat(peaks)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        for i in 0..<peaks {
            let peakX = width * (CGFloat(i) + 0.5)
            let peakY = rect.maxY - rect.height * heights[i % heights.count]
            path.addLine(to: CGPoint(x: peakX, y: peakY))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

/// A row of buildings of varying height, rising from the bottom edge.
private struct SkylineShape: Shape {
    func path(in rect: CGRect) -> Path {
        let buildings: [(x: CGFloat, w: CGFloat, h: CGFloat)] = [
            (0.02, 0.16, 0.5), (0.2, 0.15, 0.85), (0.37, 0.13, 0.6),
            (0.52, 0.18, 0.95), (0.73, 0.15, 0.65), (0.9, 0.1, 0.4),
        ]
        var path = Path()
        let baseY = rect.maxY
        path.move(to: CGPoint(x: 0, y: baseY))
        for b in buildings {
            let x = rect.width * b.x
            let w = rect.width * b.w
            let h = rect.height * b.h
            path.addLine(to: CGPoint(x: x, y: baseY - h))
            path.addLine(to: CGPoint(x: x + w, y: baseY - h))
            path.addLine(to: CGPoint(x: x + w, y: baseY))
        }
        path.addLine(to: CGPoint(x: rect.width, y: baseY))
        path.closeSubpath()
        return path
    }
}

private extension Personality {
    /// The "land" each personality's motif sits on, an environment tone
    /// rather than the personality's own accent (grass reads as green
    /// whether Mom's accent is pink or not).
    var groundColor: Color {
        switch self {
        case .mother: Color(hex: 0x4CAF6D)
        case .homie: Color(hex: 0x8A5A2B)
        case .professional: Color(hex: 0x3A4256)
        case .mentor: Color(hex: 0x3B7A57)
        case .coach: Color(hex: 0xB8461F)
        case .playful: Color(hex: 0x2A2050)
        }
    }
}
