import Foundation
import FoundationModels
import Observation
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
    var isAvailable: Bool { engine != .none }

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var sessionPersonality: Personality?
    @ObservationIgnored private var sessionInstructions: String?

    init(prefs: PreferencesStore) {
        self.prefs = prefs
    }

    func start() {
        refreshAvailability()
    }

    func refreshAvailability() {
        if case .available = SystemLanguageModel.default.availability {
            engine = .appleIntelligence
            availabilityNote = "Apple Intelligence is active. Check ins are composed on device, free."
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
    func onlineChat(system: String, prompt: String) async -> String? {
        switch engine {
        case .appleIntelligence:
            let session = LanguageModelSession(instructions: system)
            guard !session.isResponding else { return nil }
            return await Self.withTimeout(seconds: 6) {
                try? await session.respond(to: prompt, options: GenerationOptions(temperature: 0.8)).content
            }
        case .ollama(let model):
            return await OllamaClient.generate(model: model, system: system, prompt: prompt)
        case .none:
            return nil
        }
    }

    private func preparedSession(for personality: Personality, brainContext: String = "") -> LanguageModelSession {
        let instructions = Self.checkInInstructions(for: personality, brainContext: brainContext)
        if let session, sessionPersonality == personality, sessionInstructions == instructions { return session }
        let fresh = LanguageModelSession(instructions: instructions)
        session = fresh
        sessionPersonality = personality
        sessionInstructions = instructions
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
        - Do not ask questions at the end because the UI provides answer buttons automatically. Just state the context or reminder playfully or warmly.
        - Stay strictly on the single goal you are given. Never drift into asking how they are doing, \
        how their day is going, or complimenting productivity, unless the goal itself says to.
        - No lists, no quotes. Contractions are good, formal phrasing is not.
        - Use natural, conversational punctuation: contractions and the occasional exclamation mark or ellipsis are fine. NEVER use emojis.
        - Never print parentheses, timestamps, or meta labels like "(System note...)" in your reply. Those are for your eyes only, to inform what you say, not to repeat.
        - Warm and human. Never guilt trip, never lecture, never mention productivity metrics.
        - Weave the concrete facts you are given (duration, meal, meeting, minutes) into the line naturally.
        - Speak directly to the user in second person.
        """
    }

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
        case .shower: "Gently nudge them to take a shower and reset for the day."
        case .overwork: "Caringly point out the very long session and ask them to take a real break."
        case .windDown: "Their workday is over. Encourage wrapping up soon."
        case .sleep: "It is late. Encourage them to end the day and sleep."
        case .meetingPrep: "Help them get ready for the upcoming meeting."
        case .meetingRecovery: "Their meeting just ended. Suggest a tiny recovery pause."
        case .routine: "Deliver their personal routine reminder."
        case .sessionStart: "Greet them warmly as they start a fresh focus session. You MUST ask explicitly if they want you to keep watch or track breaks (it must be a strict Yes/No question). Do NOT ask open-ended questions like 'How are you feeling?'"
        case .status: "Ask how they are feeling right now, a quick mood check. They answer with one tap: Good, Am okay, or Stressing."
        case .welcome: "Reassure them you are quietly watching over their session."
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
        text = text.replacingOccurrences(
            of: #"(?:\s*[\-–—•·|/]*\s*\b(?:done|later|okay|yes|no|timer|thanks|ready)\b){2,}[\s\-–—•·|/]*$"#,
            with: "",
            options: [.regularExpression, .caseInsensitive]
        )
        text = String(text.unicodeScalars.filter { !$0.properties.isEmojiPresentation })
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
enum OllamaClient {

    private static let base = URL(string: "http:

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
