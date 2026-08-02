import AVFoundation
import SwiftUI

struct PersonalitySettingsView: View {
    @Environment(AppContainer.self) private var container
    @State private var localVoices: [AVSpeechSynthesisVoice] = []

    var body: some View {
        @Bindable var prefs = container.prefs
        Form {
            Section("Setup Vibe") {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 156), spacing: 10)], spacing: 10) {
                    ForEach(Personality.allCases) { personality in
                        PersonalityCard(
                            personality: personality,
                            isSelected: prefs.personality == personality,
                            isLocked: personality.requiresPro && !container.subscriptions.gate.allPersonalities
                        ) {
                            select(personality, prefs: prefs)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Section("Setup Voice") {
                Toggle("Speak check ins out loud", isOn: $prefs.voiceEnabled)
                    .disabled(!container.subscriptions.gate.voiceInteraction)
                    .onChange(of: prefs.voiceEnabled) { _, enabled in
                        if enabled {
                            container.voice.preview("Voice is on. I'll speak up when it matters.")
                        }
                    }
                if !container.subscriptions.gate.voiceInteraction {
                    HStack(spacing: 6) {
                        ProTag()
                        Text("Voice interaction unlocks with Pro.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                voicePicker(prefs: prefs)
                Text("Considering using your own voice? Create a Personal Voice in System Settings, Accessibility, Personal Voice, then pick it here as a voice style.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    private func select(_ personality: Personality, prefs: PreferencesStore) {
        if personality.requiresPro && !container.subscriptions.gate.allPersonalities {
            WindowPresenter.shared.showPaywall(container)
            return
        }
        prefs.personality = personality
        if prefs.voiceEnabled {
            container.voice.preview(MessageLibrary.sample(personality: personality))
        }
    }

    @ViewBuilder
    private func voicePicker(prefs: PreferencesStore) -> some View {
        @Bindable var prefs = prefs
        if container.subscriptions.gate.voiceStyles {
            HStack {
                Picker("Voice style", selection: $prefs.voiceIdentifier) {
                    Text("Automatic").tag("")
                    ForEach(localVoices, id: \.identifier) { voice in
                        Text(voiceLabel(voice)).tag(voice.identifier)
                    }
                }
                .onChange(of: prefs.voiceIdentifier) { _, identifier in
                    container.voice.preview(voiceIdentifier: identifier)
                }

                Button {
                    container.voice.preview()
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                }
                .buttonStyle(.borderless)
                .help("Hear this voice")
            }
            .onAppear {
                if localVoices.isEmpty {
                    localVoices = VoiceService.availableVoices()
                }
            }
        } else {
            HStack(spacing: 6) {
                Text("Voice styles")
                Spacer()
                ProTag(text: "PREMIUM")
                Text("System default")
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func voiceLabel(_ voice: AVSpeechSynthesisVoice) -> String {
        switch voice.quality {
        case .premium:
            return "\(voice.name) - Premium"
        case .enhanced:
            return "\(voice.name) - Enhanced"
        default:
            return voice.name
        }
    }

}

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
                    .lineLimit(3)
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
                        .frame(height: 46)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    PersonalityMotif(personality: personality)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, 4)
                        .padding(.bottom, 8)
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

/// A small, low-opacity decorative motif planted on the card's ground line,
/// hinting at that personality's vibe (e.g. flowers growing out of Mom's
/// grass) without competing with the card's text.
private struct PersonalityMotif: View {
    let personality: Personality

    private var accent: [Color] { personality.accentColors }

    /// A motif-specific icon, distinct from `symbolName` (used for
    /// functional UI elsewhere), chosen to fit the scene it's planted on
    /// rather than the personality in the abstract.
    private var motifSymbolName: String {
        switch personality {
        case .mother: "leaf.fill"
        case .homie: "basketball.fill"
        case .professional: "building.2.fill"
        case .mentor: "mountain.2.fill"
        case .coach: "flag.checkered"
        case .playful: "sparkles"
        }
    }

    var body: some View {
        Group {
            if personality == .mother {
                ZStack(alignment: .bottom) {
                    flower(size: 24).offset(x: 10)
                    flower(size: 15).offset(x: -14, y: 3)
                }
            } else {
                ZStack {
                    Image(systemName: motifSymbolName)
                        .font(.system(size: 24))
                        .foregroundStyle(accent[0].opacity(0.3))
                        .rotationEffect(.degrees(-6))
                        .offset(x: 4)
                    Image(systemName: motifSymbolName)
                        .font(.system(size: 12))
                        .foregroundStyle(accent[1].opacity(0.32))
                        .rotationEffect(.degrees(10))
                        .offset(x: -16, y: -10)
                }
            }
        }
        .frame(width: 48, height: 40, alignment: .bottom)
        .allowsHitTesting(false)
    }

    private func flower(size: CGFloat) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(accent[0].opacity(0.5))
                    .frame(width: size * 0.34, height: size * 0.62)
                    .offset(y: -size * 0.31)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle()
                .fill(accent[1].opacity(0.6))
                .frame(width: size * 0.26, height: size * 0.26)
        }
        .frame(width: size, height: size)
    }
}

/// The ground of each personality card is its own little place, not just a
/// tinted hill: a grass field for Mom, a court for Homie, a skyline for the
/// Assistant, mountains for Mentor, a track for Coach, a starfield for Spark.
private struct PersonalityScene: View {
    let personality: Personality
    let isSelected: Bool

    private var tint: Color { personality.groundColor }
    private var opacity: Double { isSelected ? 0.5 : 0.34 }
    private var lineOpacity: Double { isSelected ? 0.4 : 0.26 }

    var body: some View {
        switch personality {
        case .mother, .mentor:
            MountainShape(peaks: personality == .mentor ? 3 : 1)
                .fill(tint.opacity(opacity))
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

    private var courtLines: some View {
        ZStack {
            Rectangle()
                .fill(.white.opacity(lineOpacity))
                .frame(height: 1.2)
            Circle()
                .trim(from: 0.5, to: 1.0)
                .stroke(.white.opacity(lineOpacity), lineWidth: 1.2)
                .frame(width: 34, height: 34)
                .offset(y: -12)
        }
    }

    private var trackLines: some View {
        ZStack {
            Capsule().stroke(.white.opacity(lineOpacity), lineWidth: 1).frame(width: 90, height: 22)
            Capsule().stroke(.white.opacity(lineOpacity * 0.7), lineWidth: 1).frame(width: 70, height: 14)
        }
        .offset(y: 4)
    }

    private var starScatter: some View {
        ZStack {
            ForEach(0..<4, id: \.self) { i in
                Image(systemName: "sparkle")
                    .font(.system(size: 6 + CGFloat(i) * 2))
                    .foregroundStyle(.white.opacity(lineOpacity))
                    .offset(x: CGFloat(-20 + i * 14), y: CGFloat(-2 - i * 4))
            }
        }
    }
}

/// A gentle rising hill silhouette anchored to the bottom edge, giving each
/// card a sense of ground/land for its motif to sit on instead of floating
/// on a flat color field.
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

/// One or more overlapping triangular peaks anchored to the bottom edge:
/// a single low rise for Mom's grassy field, three for Mentor's mountains.
private struct MountainShape: Shape {
    var peaks: Int = 1

    func path(in rect: CGRect) -> Path {
        guard peaks > 1 else {
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
