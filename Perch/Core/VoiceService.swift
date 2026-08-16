import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class VoiceService: NSObject {

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()

    private(set) var isSpeaking = false

    init(prefs: PreferencesStore) {
        self.prefs = prefs
        super.init()
        synthesizer.delegate = self
    }

    func speakIfAllowed(_ text: String) {
        guard prefs.voiceEnabled, !prefs.isQuietHours() else { return }
        speak(text)
    }

    func speak(_ text: String) {
        let cleaned = Self.spokenClip(text)
        guard !cleaned.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = resolvedVoice(preferring: prefs.voiceIdentifier)
        utterance.rate = 0.47
        utterance.pitchMultiplier = 1.02
        synthesizer.speak(utterance)
    }

    func waitUntilFinished(timeout: Duration = .seconds(30)) async {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while synthesizer.isSpeaking, clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    func preview(_ text: String = "Hi, I'm Perchie. I'll speak up when it matters.", voiceIdentifier: String? = nil) {
        let cleaned = Self.spokenClip(text)
        guard !cleaned.isEmpty else { return }
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: cleaned)
        utterance.voice = resolvedVoice(preferring: voiceIdentifier ?? prefs.voiceIdentifier)
        utterance.rate = 0.47
        utterance.pitchMultiplier = 1.02
        synthesizer.speak(utterance)
    }

    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        let english = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en") }
            .sorted {
                if $0.quality != $1.quality {
                    return $0.quality.rawValue > $1.quality.rawValue
                }
                return $0.name < $1.name
            }

        var seen = Set<String>()
        return english.filter { voice in
            let key = "\(voice.name)-\(voice.language)"
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }
    }

    static func bestNaturalVoice() -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        if let premium = english.first(where: { $0.quality == .premium }) { return premium }
        if let enhanced = english.first(where: { $0.quality == .enhanced }) { return enhanced }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    static func spokenClip(_ text: String) -> String {
        let noEmoji = text.unicodeScalars.filter { scalar in
            if scalar.properties.isEmoji || scalar.properties.isEmojiPresentation || scalar.value == 0xFE0F {
                return scalar.value <= 127
            }
            return true
        }
        .map(String.init)
        .joined()
        .trimmingCharacters(in: .whitespacesAndNewlines)

        return noEmoji
    }

    private func resolvedVoice(preferring identifier: String) -> AVSpeechSynthesisVoice? {
        if !identifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        return Self.bestNaturalVoice()
    }
}

extension VoiceService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.isSpeaking = true }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.isSpeaking = false }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.isSpeaking = false }
    }
}
