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
                    PersonalityMotif(personality: personality)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                        .padding(.trailing, -6)
                        .padding(.bottom, -6)
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

/// A small, low-opacity decorative motif in the bottom-right corner of each
/// personality card, hinting at that personality's vibe (e.g. flowers for
/// Mom) without competing with the card's text.
private struct PersonalityMotif: View {
    let personality: Personality

    private var accent: [Color] { personality.accentColors }

    var body: some View {
        Group {
            if personality == .mother {
                ZStack {
                    flower(size: 30).offset(x: 8, y: 6)
                    flower(size: 18).offset(x: -16, y: 16)
                }
            } else {
                ZStack {
                    Image(systemName: personality.symbolName)
                        .font(.system(size: 34))
                        .foregroundStyle(accent[0].opacity(0.14))
                        .rotationEffect(.degrees(-8))
                        .offset(x: 10, y: 8)
                    Image(systemName: personality.symbolName)
                        .font(.system(size: 16))
                        .foregroundStyle(accent[1].opacity(0.2))
                        .rotationEffect(.degrees(12))
                        .offset(x: -14, y: -4)
                }
            }
        }
        .frame(width: 56, height: 56, alignment: .bottomTrailing)
        .allowsHitTesting(false)
    }

    private func flower(size: CGFloat) -> some View {
        ZStack {
            ForEach(0..<5, id: \.self) { i in
                Capsule()
                    .fill(accent[0].opacity(0.24))
                    .frame(width: size * 0.34, height: size * 0.62)
                    .offset(y: -size * 0.31)
                    .rotationEffect(.degrees(Double(i) * 72))
            }
            Circle()
                .fill(accent[1].opacity(0.32))
                .frame(width: size * 0.26, height: size * 0.26)
        }
        .frame(width: size, height: size)
    }
}
