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

// MARK: - Scene

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
            ZStack(alignment: .bottomLeading) {
                GroundShape().fill(tint.opacity(opacity))
                house(size: 22).padding(.leading, 10)
            }
        case .mentor:
            MountainShape(peaks: 3).fill(tint.opacity(opacity))
        case .homie:
            ZStack(alignment: .bottomTrailing) {
                Rectangle().fill(tint.opacity(opacity))
                courtLines
                hoop(size: 22).padding(.trailing, 10)
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
                windmill(size: 26)
            }
        }
    }

    private func house(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            Triangle()
                .fill(accent[0].opacity(0.42))
                .frame(width: size, height: size * 0.5)
            Rectangle()
                .fill(accent[1].opacity(0.34))
                .frame(width: size * 0.76, height: size * 0.5)
        }
    }

    private func hoop(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(.white.opacity(lineOpacity + 0.1))
                    .frame(width: size * 0.46, height: size * 0.3)
                Capsule()
                    .stroke(accent[0].opacity(0.45), lineWidth: 1.2)
                    .frame(width: size * 0.24, height: size * 0.1)
                    .offset(y: 4)
            }
            Rectangle()
                .fill(.white.opacity(lineOpacity))
                .frame(width: size * 0.05, height: size * 0.55)
        }
    }

    private func windmill(size: CGFloat) -> some View {
        VStack(spacing: 0) {
            ZStack {
                windmillBlade(color: accent[0], size: size, angle: 18)
                windmillBlade(color: accent[1], size: size, angle: 108)
                windmillBlade(color: accent[0], size: size, angle: 198)
                windmillBlade(color: accent[1], size: size, angle: 288)
            }
            .frame(width: size, height: size * 0.8)
            Rectangle()
                .fill(accent[0].opacity(0.36))
                .frame(width: size * 0.06, height: size * 0.5)
        }
    }

    private func windmillBlade(color: Color, size: CGFloat, angle: Double) -> some View {
        Capsule()
            .fill(color.opacity(0.4))
            .frame(width: size * 0.14, height: size * 0.5)
            .offset(y: -size * 0.25)
            .rotationEffect(.degrees(angle))
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
        TrackArc()
            .stroke(.white.opacity(lineOpacity), style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
            .frame(height: 16)
            .padding(.horizontal, 12)
            .padding(.bottom, 6)
    }
}

// MARK: - Shapes

private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

private struct TrackArc: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY), control: CGPoint(x: rect.midX, y: rect.minY))
        return path
    }
}

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

private struct MountainShape: Shape {
    var peaks: Int = 1

    func path(in rect: CGRect) -> Path {
        guard peaks > 1 else { return GroundShape().path(in: rect) }
        let heights: [CGFloat] = [0.55, 0.95, 0.7]
        let valley: CGFloat = 0.22
        let segment = rect.width / CGFloat(peaks)
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.maxY))
        path.addLine(to: CGPoint(x: 0, y: rect.maxY - rect.height * valley))
        for i in 0..<peaks {
            let peakX = segment * (CGFloat(i) + 0.5)
            let peakY = rect.maxY - rect.height * heights[i % heights.count]
            path.addLine(to: CGPoint(x: peakX, y: peakY))
            let valleyX = segment * CGFloat(i + 1)
            path.addLine(to: CGPoint(x: valleyX, y: rect.maxY - rect.height * valley))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

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
