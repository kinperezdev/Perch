import Foundation
import Observation

/// A fully scripted check-in chat. The companion asks one question at a time
/// grounded in the real dashboard, the user answers with Yes / No / Later
/// chips, and every reply comes from ChatScriptLibrary so questions and
/// answers always match. No AI generation anywhere in this flow.
@MainActor
@Observable
final class CompanionChatService {

    struct ChatMessage: Identifiable, Equatable, Codable {
        let id: UUID
        let isUser: Bool
        let text: String
        let date: Date

        init(isUser: Bool, text: String) {
            self.id = UUID()
            self.isUser = isUser
            self.text = text
            self.date = Date()
        }
    }

    enum Answer: Equatable {
        case yes
        case no
        case later
        case didIt
        case mood(ChatScriptLibrary.Mood)
        case log(ChatTopic)
        case allGood
    }

    struct Suggestion: Identifiable, Equatable {
        let id = UUID()
        let label: String
        let answer: Answer
    }

    private(set) var messages: [ChatMessage] = []
    private(set) var isThinking = false
    private(set) var currentEmotion: CompanionFaceView.FaceState = .idle
    private(set) var suggestions: [Suggestion] = []
    private(set) var suggestionHint = "Anything to log?"

    @ObservationIgnored private var pendingTopic: ChatTopic?
    @ObservationIgnored private var awaitingDidIt = false
    @ObservationIgnored private var declinedTopics: Set<ChatTopic> = []
    @ObservationIgnored private var hasAskedFeeling = false
    @ObservationIgnored private var responseTask: Task<Void, Never>?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored private let brain: PerchBrain
    @ObservationIgnored private let memory: HabitMemoryStore
    @ObservationIgnored private let tracker: FocusSessionTracker
    @ObservationIgnored private let voice: VoiceService

    private static let thinkingDelay: UInt64 = 650_000_000
    private static let staleConversationSeconds: TimeInterval = 30 * 60
    private static let breakQuestionAfterMinutes = 50
    private static let mealQuestionFromHour = 11
    private static let showerQuestionFromHour = 9

    private static let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Perch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chat_history.json")
    }()

    init(
        prefs: PreferencesStore,
        brain: PerchBrain,
        memory: HabitMemoryStore,
        tracker: FocusSessionTracker,
        voice: VoiceService
    ) {
        self.prefs = prefs
        self.brain = brain
        self.memory = memory
        self.tracker = tracker
        self.voice = voice
    }

    private var personality: Personality {
        prefs.activePersonality
    }

    private var callName: String {
        personality.callName(userName: prefs.userName)
    }

    // MARK: Opening

    func openIfNeeded() {
        responseTask?.cancel()
        isThinking = false
        if messages.isEmpty {
            greetAndAsk()
        } else if pendingTopic == nil,
                  let last = messages.last,
                  Date().timeIntervalSince(last.date) > Self.staleConversationSeconds,
                  let topic = nextTopic() {
            pendingTopic = topic
            awaitingDidIt = false
            deliver(ChatScriptLibrary.question(topic, personality), speak: false)
        }
        refreshSuggestions()
    }

    private func greetAndAsk() {
        let hour = Calendar.current.component(.hour, from: Date())
        let daypart = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
        var line = "Good \(daypart), \(callName)."
        if let topic = nextTopic() {
            pendingTopic = topic
            line += " " + ChatScriptLibrary.question(topic, personality)
        }
        deliver(line, speak: false)
    }

    func clear() {
        responseTask?.cancel()
        messages = []
        isThinking = false
        suggestions = []
        pendingTopic = nil
        awaitingDidIt = false
        declinedTopics = []
        hasAskedFeeling = false
        currentEmotion = .idle
    }

    // MARK: Answering

    func choose(_ suggestion: Suggestion) {
        guard !isThinking else { return }
        suggestions = []
        messages.append(ChatMessage(isUser: true, text: suggestion.label))
        if case .mood = suggestion.answer {
            brain.absorbChatMessage(suggestion.label)
        }
        responseTask?.cancel()
        responseTask = Task { [weak self] in
            await self?.respond(to: suggestion.answer)
        }
    }

    private func respond(to answer: Answer) async {
        isThinking = true
        try? await Task.sleep(nanoseconds: Self.thinkingDelay)
        guard !Task.isCancelled else { return }
        isThinking = false

        switch answer {
        case .yes, .didIt:
            guard let topic = pendingTopic, topic != .feeling else {
                finishRound(reply: nil)
                break
            }
            logHabit(topic)
            awaitingDidIt = false
            pendingTopic = nil
            finishRound(reply: ChatScriptLibrary.praise(topic, personality, callName: callName))

        case .no:
            guard let topic = pendingTopic, topic != .feeling else {
                finishRound(reply: nil)
                break
            }
            awaitingDidIt = true
            deliver(ChatScriptLibrary.nudge(topic, personality, callName: callName))
            refreshSuggestions()

        case .later:
            if let topic = pendingTopic {
                declinedTopics.insert(topic)
            }
            awaitingDidIt = false
            pendingTopic = nil
            finishRound(reply: ChatScriptLibrary.later(personality, callName: callName))

        case .mood(let mood):
            hasAskedFeeling = true
            pendingTopic = nil
            finishRound(reply: ChatScriptLibrary.moodReply(mood, personality, callName: callName))

        case .log(let topic):
            logHabit(topic)
            deliver(logConfirmation())
            refreshSuggestions()

        case .allGood:
            deliver(ChatScriptLibrary.signoff(personality, callName: callName))
            suggestions = []
        }
    }

    /// Sends the reply and, when a habit is still behind, asks the next
    /// question in the same bubble so the chips always match the question.
    private func finishRound(reply: String?) {
        var parts: [String] = []
        if let reply { parts.append(reply) }
        if let next = nextTopic() {
            pendingTopic = next
            parts.append(ChatScriptLibrary.question(next, personality))
        } else if reply != nil {
            parts.append(ChatScriptLibrary.wrapUp(personality, callName: callName))
        }
        if !parts.isEmpty {
            deliver(parts.joined(separator: " "))
        }
        refreshSuggestions()
    }

    // MARK: Dashboard grounding

    /// Picks the habit most worth asking about, straight from today's log.
    private func nextTopic() -> ChatTopic? {
        let today = memory.today()
        let hour = Calendar.current.component(.hour, from: Date())
        var behind: [ChatTopic] = []
        if today.waterCount == 0 { behind.append(.water) }
        if today.mealsLogged == 0, hour >= Self.mealQuestionFromHour { behind.append(.meal) }
        if tracker.focusRunMinutes >= Self.breakQuestionAfterMinutes, today.breaksTaken == 0 { behind.append(.breakTime) }
        if !today.showerLogged, hour >= Self.showerQuestionFromHour { behind.append(.shower) }
        if let topic = behind.first(where: { !declinedTopics.contains($0) }) { return topic }
        return hasAskedFeeling ? nil : .feeling
    }

    private func logHabit(_ topic: ChatTopic) {
        switch topic {
        case .water: memory.logWater()
        case .meal: memory.logMeal()
        case .breakTime: tracker.creditBreak()
        case .shower: memory.logShower()
        case .feeling: break
        }
    }

    private func logConfirmation() -> String {
        let variants = MessageLibrary.confirmations(response: .done, personality: personality)
        let line = variants.randomElement() ?? "Noted."
        return line.replacingOccurrences(of: "{name}", with: callName)
    }

    // MARK: Suggestions

    private func refreshSuggestions() {
        guard let topic = pendingTopic else {
            suggestions = quickLogSuggestions()
            suggestionHint = "Anything to log?"
            return
        }
        if topic == .feeling {
            suggestions = ChatScriptLibrary.Mood.allCases.map {
                Suggestion(label: $0.chipLabel, answer: .mood($0))
            }
            suggestionHint = "Pick what's closest."
        } else if awaitingDidIt {
            suggestions = [
                Suggestion(label: "Did it just now", answer: .didIt),
                Suggestion(label: "Later", answer: .later),
            ]
            suggestionHint = "Pick your answer."
        } else {
            suggestions = [
                Suggestion(label: "Yes", answer: .yes),
                Suggestion(label: "No", answer: .no),
                Suggestion(label: "Later", answer: .later),
            ]
            suggestionHint = "Pick your answer."
        }
    }

    private func quickLogSuggestions() -> [Suggestion] {
        let today = memory.today()
        var chips = [Suggestion(label: "Just drank water", answer: .log(.water))]
        if today.mealsLogged < 3 {
            chips.append(Suggestion(label: "Just ate", answer: .log(.meal)))
        }
        chips.append(Suggestion(label: "Took a break", answer: .log(.breakTime)))
        if !today.showerLogged {
            chips.append(Suggestion(label: "Just showered", answer: .log(.shower)))
        }
        chips.append(Suggestion(label: "All good", answer: .allGood))
        return chips
    }

    // MARK: Delivery

    private func deliver(_ text: String, speak: Bool = true) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        messages.append(ChatMessage(isUser: false, text: cleaned))
        currentEmotion = CompanionFaceView.FaceState.inferred(from: cleaned, fallback: .idle)
        if speak {
            voice.speakIfAllowed(cleaned)
        }
    }

    // MARK: Persistence removed per user request
}
