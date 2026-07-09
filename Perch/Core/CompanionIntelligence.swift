import Foundation
import FoundationModels
import Observation

/// Free, private intelligence with graceful fallbacks:
@MainActor
@Observable
final class CompanionIntelligence {

    enum Engine: Equatable {
        case appleIntelligence
        case ollama(model: String)
        case none
    }

    private(set) var engine: Engine = .none
    private(set) var availabilityNote = "Checking for on-device intelligence..."

    /// Cloud models are available only when the user turns on Online mode
    var isAvailable: Bool { engine != .none || onlineProvider != nil }

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var sessionPersonality: Personality?

    init(prefs: PreferencesStore) {
        self.prefs = prefs
    }

    var onlineProvider: OnlineIntelligence.Provider? {
        guard prefs.onlineMode else { return nil }
        return OnlineIntelligence.firstConfigured(prefs: prefs)
    }

    func start() {
        refreshAvailability()
    }

    func refreshAvailability() {
        if let provider = onlineProvider {
            availabilityNote = "Online mode is on. Using \(provider.label) for the smartest, most natural replies."
        }
        if case .available = SystemLanguageModel.default.availability {
            engine = .appleIntelligence
            if onlineProvider == nil {
                availabilityNote = "Apple Intelligence is active. Check ins are composed on device, free."
            }
            return
        }
        var reason = "On-device model unavailable."
        if case .unavailable(let r) = SystemLanguageModel.default.availability {
            reason = Self.describe(r)
        }
        Task { [weak self] in
            guard let self else { return }
            let model = await OllamaClient.firstModel()
            if let model { self.engine = .ollama(model: model) } else { self.engine = .none }
            guard self.onlineProvider == nil else { return }
            if let model {
                self.availabilityNote = "Using the local model \(model) through Ollama. Free and private."
            } else {
                self.availabilityNote = reason + " Perch uses its curated voice. Tip: run Ollama and it connects automatically."
            }
        }
    }

    func compose(
        kind: ReminderKind,
        personality: Personality,
        context: CheckInContext,
        callName: String,
        brainContext: String = "",
        customInstructions: String = "",
        fallback: String
    ) async -> String {
        let prompt = Self.prompt(kind: kind, context: context, callName: callName, customInstructions: customInstructions)

        if let provider = onlineProvider {
            let system = Self.checkInInstructions(for: personality, brainContext: brainContext)
            let online = await Self.withTimeout(seconds: 12) {
                await OnlineIntelligence.generate(provider: provider, system: system, prompt: prompt)
            }
            if let online, let cleaned = Self.sanitize(online) { return cleaned }
        }

        let raw: String?
        switch engine {
        case .appleIntelligence:
            let session = preparedSession(for: personality, brainContext: brainContext)
            guard !session.isResponding else { return fallback }
            raw = await Self.withTimeout(seconds: 3.5) {
                try? await session.respond(
                    to: prompt,
                    options: GenerationOptions(temperature: 0.8)
                ).content
            }
        case .ollama(let model):
            let system = Self.checkInInstructions(for: personality, brainContext: brainContext)
            raw = await Self.withTimeout(seconds: 6) {
                await OllamaClient.generate(model: model, system: system, prompt: prompt)
            }
        case .none:
            raw = nil
        }
        guard let raw, let cleaned = Self.sanitize(raw) else { return fallback }
        return cleaned
    }

    /// Chat path: online when configured, else local Ollama. Apple
    func onlineChat(system: String, prompt: String) async -> String? {
        if let provider = onlineProvider {
            let online = await Self.withTimeout(seconds: 15) {
                await OnlineIntelligence.generate(provider: provider, system: system, prompt: prompt)
            }
            if let online, !online.isEmpty { return online }
        }
        if case .ollama(let model) = engine {
            return await OllamaClient.generate(model: model, system: system, prompt: prompt)
        }
        return nil
    }

    // MARK: Sessions and instructions

    private func preparedSession(for personality: Personality, brainContext: String = "") -> LanguageModelSession {
        if let session, sessionPersonality == personality, brainContext.isEmpty { return session }
        let fresh = LanguageModelSession(instructions: Self.checkInInstructions(for: personality, brainContext: brainContext))
        fresh.prewarm()
        session = fresh
        sessionPersonality = personality
        return fresh
    }

    static func checkInInstructions(for personality: Personality, brainContext: String = "") -> String {
        let memoryBlock = brainContext.isEmpty ? "" : """

        What Perch remembers about this person:
        \(brainContext)
        Use this to make check ins feel personal and earned, not generic.
        """
        return """
        You are Perch, a tiny wellbeing companion living near the notch of a Mac. \
        The user is a builder in deep focus. You speak as \(personality.styleBrief)\(memoryBlock)

        Rules you must always follow:
        - One short check in line only, like something a friend would say out loud. Under 18 words.
        - Always end with a caring question that invites a quick reply (yes / no / later).
        - No lists, no quotes. Contractions are good, formal phrasing is not.
        - Use highly expressive texting punctuation! Emphasize feelings with exclamation marks (!), use question marks (?), trailing ellipses (...) to sound conversational, and feel free to use emojis that fit your vibe!
        - Warm and human. Never guilt trip, never lecture, never mention productivity metrics.
        - Weave the concrete facts you are given (duration, meal, meeting, minutes) into the line naturally.
        - Speak directly to the user in second person.
        """
    }

    // MARK: Helpers

    private static func prompt(kind: ReminderKind, context: CheckInContext, callName: String, customInstructions: String = "") -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .long
        let now = f.string(from: Date())
        var facts: [String] = [
            "You may initially address the user as \"\(callName)\", but if the brain context suggests a different nickname or specific slang based on how they talk, you should adapt your wordings to match their vibe.",
            "The current date and local time is \(now)."
        ]
        if let minutes = context.minutes, minutes > 0 {
            facts.append("They have been working for \(humanDuration(minutes: minutes)) without a real break.")
        }
        if let meal = context.mealName {
            facts.append("It is around their usual \(meal) time.")
            if context.yesterdaySkipped { facts.append("They skipped \(meal) around this time yesterday.") }
        }
        if let event = context.eventTitle, let mins = context.minutesUntil {
            facts.append("Their meeting \"\(event)\" starts in \(mins) minutes.")
        }
        if let routine = context.routineLabel {
            facts.append("They asked to be reminded about: \(routine).")
        }
        let goal: String = switch kind {
        case .water: "Gently get them to drink water now."
        case .stretch: "Gently get them to stand and stretch for a minute."
        case .eyes: "Gently get them to rest their eyes on something distant for twenty seconds."
        case .posture: "Gently get them to fix their posture."
        case .walk: "Suggest a short five minute walk."
        case .meal: "Check whether they have eaten, and encourage a real meal break."
        case .overwork: "Caringly point out the very long session and ask them to take a real break."
        case .windDown: "Their workday is over. Encourage wrapping up soon."
        case .sleep: "It is late. Encourage them to end the day and sleep."
        case .meetingPrep: "Help them get ready for the upcoming meeting."
        case .meetingRecovery: "Their meeting just ended. Suggest a tiny recovery pause."
        case .routine: "Deliver their personal routine reminder."
        case .sessionStart: "Greet them warmly as they start a fresh focus session and promise to keep watch."
        case .status, .welcome: "Reassure them you are quietly watching over their session."
        }
        facts.append("Goal: \(goal)")
        if !customInstructions.isEmpty {
            facts.append("Strict personality rules:\n\(customInstructions)")
        }
        facts.append("Reply with the single check in line only.")
        return facts.joined(separator: "\n")
    }

    private static func sanitize(_ raw: String) -> String? {
        var text = raw
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        text = text.trimmingCharacters(in: CharacterSet(charactersIn: "\"'`"))
        guard !text.isEmpty, text.count <= 220 else { return nil }
        return text
    }

    private static func withTimeout(seconds: Double, operation: @escaping () async -> String?) async -> String? {
        await withTaskGroup(of: String?.self) { group in
            group.addTask { await operation() }
            group.addTask {
                try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            "This Mac does not support Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            "Apple Intelligence is turned off in System Settings."
        case .modelNotReady:
            "The Apple Intelligence model is still downloading."
        @unknown default:
            "Apple Intelligence is unavailable."
        }
    }
}

// MARK: - Ollama

/// Minimal client for a local Ollama server. Loopback only,
enum OllamaClient {

    private static let base = URL(string: "http://127.0.0.1:11434")!

    static func firstModel() async -> String? {
        struct Tags: Decodable {
            struct Model: Decodable { let name: String }
            let models: [Model]
        }
        var request = URLRequest(url: base.appendingPathComponent("api/tags"))
        request.timeoutInterval = 1.5
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        return (try? JSONDecoder().decode(Tags.self, from: data))?.models.first?.name
    }

    static func generate(model: String, system: String, prompt: String) async -> String? {
        struct Body: Encodable {
            let model: String
            let system: String
            let prompt: String
            let stream: Bool
        }
        struct Reply: Decodable { let response: String }
        var request = URLRequest(url: base.appendingPathComponent("api/generate"))
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONEncoder().encode(
            Body(model: model, system: system, prompt: prompt, stream: false)
        )
        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return nil }
        let reply = (try? JSONDecoder().decode(Reply.self, from: data))?.response
        return reply?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
