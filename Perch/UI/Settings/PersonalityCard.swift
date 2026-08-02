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

    private var tint: Color { personality.groundColor }
    private var opacity: Double { isSelected ? 0.4 : 0.26 }

    var body: some View {
        switch personality {
        case .mentor:
            AnyShape(MountainShape(peaks: 3)).fill(tint.opacity(opacity))
        case .professional:
            AnyShape(SkylineShape()).fill(tint.opacity(opacity))
        case .mother:
            FlowerSymbol(tint: tint.opacity(opacity))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 4)
        case .homie:
            symbol(HeadphonesShape(), width: 30, height: 26)
        case .coach:
            symbol(FlagShape(), width: 22, height: 28)
        case .playful:
            symbol(StarShape(), width: 26, height: 26)
        }
    }

    private func symbol(_ shape: some Shape, width: CGFloat, height: CGFloat) -> some View {
        shape
            .fill(tint.opacity(opacity))
            .frame(width: width, height: height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
    }
}

// MARK: - Shapes

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

private struct FlowerSymbol: View {
    let tint: Color

    var body: some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Ellipse()
                    .fill(tint)
                    .frame(width: 8, height: 12)
                    .offset(y: -6)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
        }
        .frame(width: 26, height: 26)
    }
}

private struct HeadphonesShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let bandThickness = rect.width * 0.14
        let outerRadius = rect.width / 2
        let innerRadius = outerRadius - bandThickness
        let center = CGPoint(x: rect.midX, y: rect.minY + outerRadius)
        path.addArc(center: center, radius: outerRadius, startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
        path.addArc(center: center, radius: innerRadius, startAngle: .degrees(0), endAngle: .degrees(180), clockwise: true)
        path.closeSubpath()

        let earWidth = rect.width * 0.2
        let earHeight = rect.height * 0.42
        let earY = rect.maxY - earHeight
        path.addRoundedRect(
            in: CGRect(x: rect.minX, y: earY, width: earWidth, height: earHeight),
            cornerSize: CGSize(width: earWidth * 0.4, height: earWidth * 0.4)
        )
        path.addRoundedRect(
            in: CGRect(x: rect.maxX - earWidth, y: earY, width: earWidth, height: earHeight),
            cornerSize: CGSize(width: earWidth * 0.4, height: earWidth * 0.4)
        )
        return path
    }
}

private struct FlagShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let poleWidth = rect.width * 0.16
        path.addRect(CGRect(x: rect.minX, y: rect.minY, width: poleWidth, height: rect.height))
        path.move(to: CGPoint(x: rect.minX + poleWidth, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + rect.height * 0.22))
        path.addLine(to: CGPoint(x: rect.minX + poleWidth, y: rect.minY + rect.height * 0.44))
        path.closeSubpath()
        return path
    }
}

private struct StarShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let midX = rect.midX
        let midY = rect.midY
        let w = rect.width
        let h = rect.height
        path.move(to: CGPoint(x: midX, y: rect.minY))
        path.addQuadCurve(to: CGPoint(x: rect.maxX, y: midY), control: CGPoint(x: midX + w * 0.12, y: midY - h * 0.12))
        path.addQuadCurve(to: CGPoint(x: midX, y: rect.maxY), control: CGPoint(x: midX + w * 0.12, y: midY + h * 0.12))
        path.addQuadCurve(to: CGPoint(x: rect.minX, y: midY), control: CGPoint(x: midX - w * 0.12, y: midY + h * 0.12))
        path.addQuadCurve(to: CGPoint(x: midX, y: rect.minY), control: CGPoint(x: midX - w * 0.12, y: midY - h * 0.12))
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
        case .mother: Color(hex: 0xFF8FA3)
        case .homie: Color(hex: 0x8A5A2B)
        case .professional: Color(hex: 0x3A4256)
        case .mentor: Color(hex: 0x3B7A57)
        case .coach: Color(hex: 0xB8461F)
        case .playful: Color(hex: 0x2A2050)
        }
    }
}
