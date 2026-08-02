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
