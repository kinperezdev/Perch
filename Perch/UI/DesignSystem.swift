import SwiftUI

// MARK: - Color helpers

extension Color {
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Perch look

enum PerchStyle {
    static let scale: CGFloat = 0.85

    static let bubbleRadius: CGFloat = 26 * scale
    static let cardRadius: CGFloat = 16 * scale

    static func accentGradient(_ colors: [Color]) -> LinearGradient {
        LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension Font {
    static func perchRounded(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size * PerchStyle.scale, weight: weight, design: .rounded)
    }
}

// MARK: - Button styles

/// Filled pill used for the primary action inside the notch bubble.
struct PillButtonStyle: ButtonStyle {
    var accent: [Color]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.perchRounded(11.5, weight: .semibold))
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 11)
            .padding(.vertical, 5)
            .background(PerchStyle.accentGradient(accent), in: Capsule())
            .opacity(configuration.isPressed ? 0.7 : 1)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Quiet pill for secondary actions on the dark bubble.
struct GhostPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.perchRounded(11.5, weight: .medium))
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.12), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Small round icon button on the dark bubble.
struct IconPillButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 10.5, weight: .semibold))
            .foregroundStyle(.white.opacity(0.75))
            .frame(width: 24, height: 24)
            .background(.white.opacity(configuration.isPressed ? 0.22 : 0.1), in: Circle())
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

/// Prominent rounded button used across onboarding and paywall.
struct BigActionButtonStyle: ButtonStyle {
    var accent: [Color]

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.perchRounded(15, weight: .semibold))
            .foregroundStyle(.black.opacity(0.85))
            .padding(.horizontal, 28)
            .padding(.vertical, 11)
            .background(PerchStyle.accentGradient(accent), in: Capsule())
            .shadow(color: accent.first?.opacity(0.35) ?? .clear, radius: 12, y: 4)
            .opacity(configuration.isPressed ? 0.75 : 1)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Shared small views

struct ProTag: View {
    var text = "PRO"

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                LinearGradient(colors: [Color(hex: 0x7B6CFF), Color(hex: 0x4FA6FF)],
                               startPoint: .leading, endPoint: .trailing),
                in: Capsule()
            )
    }
}

struct StatRow: View {
    let symbol: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 16)
            Text(label)
                .font(.perchRounded(12))
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.perchRounded(12, weight: .semibold))
                .monospacedDigit()
        }
    }
}
