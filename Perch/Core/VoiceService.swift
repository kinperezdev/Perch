import AVFoundation
import Foundation
import Observation
import Speech

/// Spoken check ins plus short voice replies. Speech recognition runs
@MainActor
@Observable
final class VoiceService {

    private(set) var isListening = false
    private(set) var transcript = ""
    private(set) var speechAuthorized = SFSpeechRecognizer.authorizationStatus() == .authorized
    private(set) var listeningAuthorized =
        SFSpeechRecognizer.authorizationStatus() == .authorized
        && AVCaptureDevice.authorizationStatus(for: .audio) == .authorized

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private let audioEngine = AVAudioEngine()
    @ObservationIgnored private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @ObservationIgnored private var recognitionTask: SFSpeechRecognitionTask?
    @ObservationIgnored private var listenTimeout: Task<Void, Never>?
    @ObservationIgnored private var onFinal: ((String) -> Void)?

    init(prefs: PreferencesStore) {
        self.prefs = prefs
    }

    // MARK: Speaking

    func speakIfAllowed(_ text: String) {
        guard prefs.voiceEnabled, !prefs.isQuietHours() else { return }
        speak(text)
    }

    func speak(_ text: String) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: Self.spokenClip(text))
        utterance.voice = resolvedVoice(preferring: prefs.voiceIdentifier)
        utterance.rate = 0.47
        utterance.pitchMultiplier = 1.02
        synthesizer.speak(utterance)
    }

    /// Chosen voice if set, otherwise the most natural voice on this Mac:
    private func resolvedVoice(preferring identifier: String) -> AVSpeechSynthesisVoice? {
        if !identifier.isEmpty, let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice
        }
        return Self.bestNaturalVoice()
    }

    static func bestNaturalVoice() -> AVSpeechSynthesisVoice? {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        if let premium = english.first(where: { $0.quality == .premium }) { return premium }
        if let enhanced = english.first(where: { $0.quality == .enhanced }) { return enhanced }
        return AVSpeechSynthesisVoice(language: "en-US")
    }

    /// Spoken lines stay short and human: at most two sentences.
    static func spokenClip(_ text: String) -> String {
        let noEmoji = text.unicodeScalars.filter { scalar in
            if scalar.properties.isEmoji || scalar.properties.isEmojiPresentation || scalar.value == 0xFE0F {
                if scalar.value <= 127 { return true }
                return false
            }
            return true
        }.map(String.init).joined()
        
        let sentences = noEmoji.split(separator: ".", omittingEmptySubsequences: true)
        guard sentences.count > 2 else { return noEmoji }
        return sentences.prefix(2).joined(separator: ".") + "."
    }

    /// Explicit user preview: always audible, ignores quiet hours and the
    func preview(_ text: String = "Hi, I'm Perch. I'll be looking out for you.", voiceIdentifier: String? = nil) {
        if synthesizer.isSpeaking { synthesizer.stopSpeaking(at: .immediate) }
        let utterance = AVSpeechUtterance(string: Self.spokenClip(text))
        utterance.voice = resolvedVoice(preferring: voiceIdentifier ?? prefs.voiceIdentifier)
        utterance.rate = 0.47
        utterance.pitchMultiplier = 1.02
        synthesizer.speak(utterance)
    }

    static func availableVoices() -> [AVSpeechSynthesisVoice] {
        let english = AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("en") }
        var finalVoices: [AVSpeechSynthesisVoice] = []
        if #available(macOS 14.0, *) {
            finalVoices = english.filter { $0.voiceTraits.contains(.isPersonalVoice) }
        }
        
        let sortedByQuality = english.sorted { 
            if $0.quality != $1.quality { return $0.quality.rawValue > $1.quality.rawValue }
            return $0.name < $1.name
        }
        
        var uniqueNames = Set<String>(finalVoices.map(\.name))
        for voice in sortedByQuality {
            if !uniqueNames.contains(voice.name) {
                uniqueNames.insert(voice.name)
                finalVoices.append(voice)
            }
            if finalVoices.count >= (6 + (finalVoices.filter { uniqueNames.contains($0.name) }.count)) { break }
        }
        return finalVoices
    }

    // MARK: Permissions

    func requestListeningPermissions() async -> Bool {
        if SFSpeechRecognizer.authorizationStatus() == .authorized,
           AVCaptureDevice.authorizationStatus(for: .audio) == .authorized {
            speechAuthorized = true
            listeningAuthorized = true
            return true
        }
        let speechStatus = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
        speechAuthorized = speechStatus == .authorized
        guard speechAuthorized else {
            listeningAuthorized = false
            return false
        }
        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        listeningAuthorized = micGranted
        return micGranted
    }

    // MARK: Listening

    func startListening(onFinal: @escaping (String) -> Void) {
        guard !isListening else { return }
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")), recognizer.isAvailable else {
            onFinal("")
            return
        }
        self.onFinal = onFinal
        transcript = ""

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            request.requiresOnDeviceRecognition = true
        }
        recognitionRequest = request

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        do {
            audioEngine.prepare()
            try audioEngine.start()
        } catch {
            finishListening(deliver: true)
            return
        }
        isListening = true

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor [weak self] in
                guard let self, self.isListening else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal { self.finishListening(deliver: true) }
                }
                if error != nil { self.finishListening(deliver: true) }
            }
        }

        listenTimeout = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.finishListening(deliver: true) }
        }
    }

    func stopListening(deliver: Bool = true) {
        finishListening(deliver: deliver)
    }

    private func finishListening(deliver: Bool) {
        guard isListening || recognitionTask != nil else { return }
        isListening = false
        listenTimeout?.cancel()
        listenTimeout = nil
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        let text = transcript
        let callback = onFinal
        onFinal = nil
        if deliver { callback?(text) }
    }

    // MARK: Interpretation

    /// Maps a short spoken reply onto a check in response.
    static func interpret(_ transcript: String) -> CheckInResponse? {
        let text = transcript.lowercased()
        guard !text.isEmpty else { return nil }
        let snoozeWords = ["later", "snooze", "in a bit", "not now", "busy", "few minutes", "soon", "wait"]
        if snoozeWords.contains(where: text.contains) { return .snoozed(minutes: 10) }
        let doneWords = ["done", "did it", "yes", "yeah", "yep", "okay", "ok", "sure", "finished", "ate", "already", "drank", "got it", "on it", "will do"]
        if doneWords.contains(where: text.contains) { return .done }
        let ignoreWords = ["no", "nah", "skip", "stop", "ignore", "leave me", "dismiss"]
        if ignoreWords.contains(where: text.contains) { return .ignored }
        return nil
    }
}
