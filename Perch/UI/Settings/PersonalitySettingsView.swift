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
                            isSelected: !prefs.usesCustomPersonality && prefs.personality == personality,
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
            }
            Section("Custom companion") {
                customPersonalityEditor(prefs: prefs)
            }
            Section("On-device intelligence") {
                Label(container.intelligence.availabilityNote, systemImage: "brain")
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
        prefs.usesCustomPersonality = false
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

    @ViewBuilder
    private func customPersonalityEditor(prefs: PreferencesStore) -> some View {
        @Bindable var prefs = prefs
        if container.subscriptions.gate.customPersonality {
            Toggle("Use a custom companion", isOn: $prefs.usesCustomPersonality)
            if prefs.usesCustomPersonality {
                TextField("Companion name", text: $prefs.customCompanionName)
                Picker("Base style", selection: $prefs.customBaseStyle) {
                    ForEach(Personality.allCases) { personality in
                        Text(personality.displayName).tag(personality)
                    }
                }
                TextField("Signature phrase", text: $prefs.customSignoff, prompt: Text("e.g. Now go build."))
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Custom AI Rules (System Prompt)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Import Brain") {
                            importBrain(prefs: prefs)
                        }
                        .font(.caption)
                    }
                    TextEditor(text: $prefs.customInstructions)
                        .font(.system(size: 11, design: .monospaced))
                        .frame(height: 60)
                        .padding(4)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        } else {
            HStack(spacing: 6) {
                Text("Name your own companion and tune its voice.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                ProTag(text: "PREMIUM")
            }
        }
    }

    private func importBrain(prefs: PreferencesStore) {
        if let text = importInstructionsFile() {
            prefs.customInstructions = text
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
                    CompanionFaceView(state: isSelected ? .excited : .idle, accent: personality.accentColors, size: 24)
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
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(personality.accentColors[0].opacity(0.12)) : AnyShapeStyle(.quaternary.opacity(0.4)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(isSelected ? personality.accentColors[0].opacity(0.6) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
    }
}
