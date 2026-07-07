import Foundation
import FoundationModels
import Observation
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

    private(set) var messages: [ChatMessage] = []
    private(set) var isThinking = false
    private(set) var currentEmotion: CompanionFaceView.FaceState = .idle
    private(set) var suggestions: [String] = []

    @ObservationIgnored private var suggestionTask: Task<Void, Never>?
    @ObservationIgnored private var responseTask: Task<Void, Never>?
    @ObservationIgnored private var activeResponseMessageID: UUID?

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored let intelligence: CompanionIntelligence
    @ObservationIgnored private let brain: PerchBrain
    @ObservationIgnored private let memory: HabitMemoryStore
    @ObservationIgnored private let tracker: FocusSessionTracker
    @ObservationIgnored private let voice: VoiceService
    @ObservationIgnored private let gateProvider: () -> FeatureGate
    @ObservationIgnored private var session: LanguageModelSession?
    @ObservationIgnored private var sessionPersonality: Personality?
    @ObservationIgnored private var saveTask: Task<Void, Never>?

    private static let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Perch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("chat_history.json")
    }()

    init(
        prefs: PreferencesStore,
        intelligence: CompanionIntelligence,
        brain: PerchBrain,
        memory: HabitMemoryStore,
        tracker: FocusSessionTracker,
        voice: VoiceService,
        gateProvider: @escaping () -> FeatureGate
    ) {
        self.prefs = prefs
        self.intelligence = intelligence
        self.brain = brain
        self.memory = memory
        self.tracker = tracker
        self.voice = voice
        self.gateProvider = gateProvider
        load()
    }

    private var personality: Personality {
        prefs.activePersonality
    }



    private func dashboardContext() -> String {
        let today = memory.today()


        let focusMinutes = (tracker.focusRunMinutes / 10) * 10
        var facts: [String] = []
        facts.append(tracker.focusRunMinutes > 0
            ? "Current focus session: \(focusMinutes == 0 ? "just started" : "about \(focusMinutes) min")"
            : "No active focus session right now")
        facts.append("Water today: \(today.waterCount) glass\(today.waterCount == 1 ? "" : "es")")
        facts.append("Meals logged: \(today.mealsLogged) of 3")
        facts.append("Breaks taken: \(today.breaksTaken)")
        facts.append("Shower: \(today.showerLogged ? "done" : "not yet")")
        return facts.joined(separator: ". ") + "."
    }
    func openIfNeeded() {
        guard messages.isEmpty else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        let daypart = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
        let greeting = "Good \(daypart), \(personality.callName(userName: prefs.userName)). " + SupportLibrary.greeting(personality)
        messages.append(ChatMessage(isUser: false, text: greeting))
        updateSuggestions(for: greeting)
        scheduleSave()
    }

    func injectCheckIn(_ text: String) {
        if let last = messages.last, last.text == text, !last.isUser { return }
        messages.append(ChatMessage(isUser: false, text: text))
        currentEmotion = CompanionFaceView.FaceState.inferred(from: text, fallback: .idle)
        updateSuggestions(for: text)
        scheduleSave()
    }
    func injectSilentMessage(isUser: Bool, text: String) {
        messages.append(ChatMessage(isUser: isUser, text: text))
        if isUser {
            brain.absorbChatMessage(text)
        } else {
            currentEmotion = CompanionFaceView.FaceState.inferred(from: text, fallback: .idle)
            updateSuggestions(for: text)
        }
        scheduleSave()
    }

    func clear() {
        suggestionTask?.cancel()
        responseTask?.cancel()
        saveTask?.cancel()
        messages = []
        isThinking = false
        suggestions = []
        activeResponseMessageID = nil
        currentEmotion = .idle
        session = nil
        sessionPersonality = nil
        sessionInstructions = nil
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        suggestionTask?.cancel()
        suggestions = []
        let message = ChatMessage(isUser: true, text: text)
        messages.append(message)
        brain.absorbChatMessage(text)
        activeResponseMessageID = message.id
        scheduleSave()
        responseTask?.cancel()
        responseTask = Task { [weak self] in
            await self?.respond(to: text, messageID: message.id)
        }
    }

    private func respond(to text: String, messageID: UUID) async {
        if SupportLibrary.mentionsSeriousDistress(text) {
            guard activeResponseMessageID == messageID else { return }
            activeResponseMessageID = nil
            deliver(SupportLibrary.safetyResponse)
            return
        }
        isThinking = true
        var reply: String? = nil
        if intelligence.isAvailable, gateProvider().aiChat {
            reply = await aiReply(to: text)
        }
        guard !Task.isCancelled, activeResponseMessageID == messageID else {
            isThinking = false
            return
        }


        if let candidate = reply, let previous = messages.last(where: { !$0.isUser })?.text,
           Self.isNearDuplicate(candidate, previous) {
            reply = nil
        }
        activeResponseMessageID = nil
        isThinking = false
        let finalReply = reply ?? SupportLibrary.acknowledgement(personality, callName: personality.callName(userName: prefs.userName))
        deliver(finalReply)
        if reply != nil {
            learnFromExchange(userText: text, aiText: finalReply)
        }
    }

    private static func isNearDuplicate(_ a: String, _ b: String) -> Bool {
        let normalizedA = a.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedB = b.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        if normalizedA == normalizedB { return true }
        let wordsA = Set(normalizedA.split(separator: " "))
        let wordsB = Set(normalizedB.split(separator: " "))
        guard !wordsA.isEmpty, !wordsB.isEmpty else { return false }
        let overlap = wordsA.intersection(wordsB).count
        let ratio = Double(overlap) / Double(max(wordsA.count, wordsB.count))
        return ratio > 0.75
    }

    private func learnFromExchange(userText: String, aiText: String) {
        guard intelligence.isAvailable else { return }
        Task { [weak self] in
            await self?.extractAndStoreMemory(userText: userText, aiText: aiText)
        }
    }

    private func extractAndStoreMemory(userText: String, aiText: String) async {
        let existing = brain.contextSummary()
        let system = """
        You extract durable, useful facts about a user from one chat exchange to build a long-term memory profile for their wellbeing companion app. \
        Only extract facts worth remembering long-term: their name, goals, projects, preferences, recurring struggles or moods, or important events. \
        Ignore small talk, filler, and anything already known below. \
        Reply with each new fact on its own line, formatted exactly as: [category] fact text. \
        Valid categories: name, goal, project, preference, habit, struggle, note. \
        Keep each fact under 20 words. \
        If nothing new and durable is worth remembering, reply with exactly: NONE
        """
        let prompt = """
        What the companion already remembers: \(existing.isEmpty ? "Nothing yet." : existing)

        New exchange:
        User: \(userText)
        Companion: \(aiText)

        Extract new durable facts, if any.
        """
        guard let result = await intelligence.onlineChat(system: system, prompt: prompt) else { return }
        let trimmed = result.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.uppercased() != "NONE", !trimmed.isEmpty else { return }
        for rawLine in trimmed.split(separator: "\n") {
            let line = String(rawLine).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            guard line.hasPrefix("["), let closeBracket = line.firstIndex(of: "]") else {
                brain.absorbAIInsight(line, category: "note")
                continue
            }
            let category = String(line[line.index(after: line.startIndex)..<closeBracket])
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased()
            let fact = String(line[line.index(after: closeBracket)...]).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !fact.isEmpty else { continue }
            brain.absorbAIInsight(fact, category: category)
        }
    }

    private func deliver(_ text: String) {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return }
        messages.append(ChatMessage(isUser: false, text: cleaned))
        currentEmotion = CompanionFaceView.FaceState.inferred(from: cleaned, fallback: .idle)
        voice.speakIfAllowed(cleaned)
        updateSuggestions(for: cleaned)
        scheduleSave()
    }

    private func updateSuggestions(for aiText: String) {
        suggestionTask?.cancel()
        guard intelligence.isAvailable, gateProvider().aiChat else {
            suggestions = fallbackChips()
            return
        }

        let aiName = prefs.usesCustomPersonality && !prefs.customCompanionName.isEmpty ? prefs.customCompanionName : "Perch"
        let prompt = """
        The companion (\(aiName)) just said this to the user:
        "\(aiText)"

        The user's day so far: \(dashboardContext())

        Generate exactly 4 short, distinct replies the user might tap, grounded in their day: \
        how the focus session feels, water, meals, breaks, or shower. \
        Each reply must be under 6 words, first person, like "Just drank some water".
        Reply with ONLY the 4 replies separated by the '|' character. No preamble, no numbering, no explanation, nothing else.
        Example output, word for word: Just drank some water|Haven't eaten yet|Taking a break now|Locked in, feeling good
        """

        suggestionTask = Task { [weak self] in
            guard let self else { return }
            if let online = await self.intelligence.onlineChat(system: "You generate quick reply suggestions.", prompt: prompt) {
                if Task.isCancelled { return }
                let chips = Self.sanitizedChips(from: online)
                if chips.count >= 2 {
                    self.suggestions = chips
                }
            }
        }
    }



    private func fallbackChips() -> [String] {
        let today = memory.today()
        var chips: [String] = []
        chips.append(tracker.focusRunMinutes > 0 ? "Deep in a focus session" : "Just getting started")
        chips.append(today.waterCount == 0 ? "Haven't had water yet" : "Just drank some water")
        chips.append(today.mealsLogged == 0 ? "Haven't eaten yet" : "Already ate, all good")
        chips.append(today.breaksTaken == 0 ? "No breaks so far" : "Took a break earlier")
        return chips
    }




    private static func sanitizedChips(from raw: String) -> [String] {
        raw.split(separator: "|")
            .map { piece -> String in
                var cleaned = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                cleaned = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"'` \n\t"))
                cleaned = cleaned.replacingOccurrences(
                    of: #"^\s*(here (are|is)[^:]*:|sure[,:]?|okay[,:]?|\d+[\.)])\s*"#,
                    with: "",
                    options: [.regularExpression, .caseInsensitive]
                )
                return cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { chip in
                guard !chip.isEmpty, chip.count <= 40 else { return false }
                let wordCount = chip.split(separator: " ").count
                guard wordCount >= 1, wordCount <= 8 else { return false }
                let lowered = chip.lowercased()
                let bannedPhrases = ["here are", "here is", "replies:", "reply:", "sure,", "natural replies"]
                return !bannedPhrases.contains { lowered.contains($0) }
            }
            .prefix(4)
            .map { $0 }
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 800_000_000)
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted]
        let toSave = Array(messages.suffix(200))
        guard let data = try? encoder.encode(toSave) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode([ChatMessage].self, from: data) {
            messages = decoded
            if let last = messages.last, !last.isUser {
                updateSuggestions(for: last.text)
            }
        }
    }

    private func aiReply(to text: String) async -> String? {
        let aiName = prefs.usesCustomPersonality && !prefs.customCompanionName.isEmpty ? prefs.customCompanionName : "Perch"
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        let timeString = formatter.string(from: Date())

        let priorMessages = messages.dropLast().suffix(6)
        let transcript = priorMessages
            .map { ($0.isUser ? "User: " : "\(aiName): ") + $0.text }
            .joined(separator: "\n")

        let onlinePrompt = """
        \(transcript)
        (System note: Time is \(timeString))
        User: \(text)
        \(aiName):
        """.trimmingCharacters(in: .whitespacesAndNewlines)

        if let online = await intelligence.onlineChat(system: chatInstructions(), prompt: onlinePrompt),
           !online.isEmpty {
            let cleaned = Self.normalizedReply(online, aiName: aiName)
            return cleaned.isEmpty ? nil : Self.clipped(cleaned)
        }

        if case .appleIntelligence = intelligence.engine {
            let session = preparedSession()
            guard !session.isResponding else { return nil }
            do {
                let contextMessage = "(System note: Time is \(timeString))\nUser: \(text)"
                let response = try await session.respond(
                    to: contextMessage,
                    options: GenerationOptions(temperature: 0.7)
                )
                let cleaned = Self.clipped(Self.normalizedReply(response.content, aiName: aiName))
                return cleaned.isEmpty ? nil : cleaned
            } catch {
                return nil
            }
        }
        return nil
    }

    private static func normalizedReply(_ text: String, aiName: String) -> String {
        var cleaned = stripAIPrefix(from: text.trimmingCharacters(in: .whitespacesAndNewlines), aiName: aiName)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        for _ in 0..<3 {
            guard cleaned.hasPrefix("("), let closeRange = cleaned.range(of: ")") else { break }
            cleaned = String(cleaned[closeRange.upperBound...]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "\"'` \n\t"))
    }

    private static func clipped(_ text: String) -> String {
        guard text.count > 140 else { return text }
        let sentences = text.split(separator: ".", omittingEmptySubsequences: true)
        guard sentences.count > 1 else { return String(text.prefix(140)) }
        return sentences.prefix(1).joined(separator: ".") + "."
    }

    @ObservationIgnored private var sessionInstructions: String?

    private func preparedSession() -> LanguageModelSession {
        let currentInstructions = chatInstructions()
        if let session, sessionPersonality == personality, sessionInstructions == currentInstructions {
            return session
        }
        let fresh = LanguageModelSession(instructions: currentInstructions)
        session = fresh
        sessionPersonality = personality
        sessionInstructions = currentInstructions
        return fresh
    }

    private func chatInstructions() -> String {
        let aiName = prefs.usesCustomPersonality && !prefs.customCompanionName.isEmpty ? prefs.customCompanionName : "Perch"
        let call = personality.callName(userName: prefs.userName)
        let brainContext = brain.contextSummary()
        let memoryBlock = brainContext.isEmpty ? "" : "\n\nWhat \(aiName) remembers about this person:\n\(brainContext)\nUse this context if relevant to the chat."



        let sleepRule = prefs.isQuietHours()
            ? """
              - CRITICAL RULE: It is currently quiet hours (late at night). If they are still working or chatting, you MUST explicitly state the exact time and forcefully tell them to go to sleep. You must convey this exact meaning: "It's already [Time] and I know you are putting some work in today, but I want you to keep yourself healthy because your health is important to me and for your future. Now go to sleep, okay? Goodnight \(call)." You MUST phrase this firmly but adapt the words to perfectly match your specific personality! HOWEVER, if they are already saying goodnight or agreeing to sleep, do NOT repeat the warning. Just warmly say goodnight back and let them rest! Only deliver this warning once per conversation, do not repeat it verbatim on later turns, just gently reiterate in different words if they keep talking.
              """
            : """
              - It is not late right now, so do not mention sleep, bedtime, or "it's getting late" at all unless they bring it up first.
              """

        var base = """
        You are \(aiName), a small wellbeing companion who lives near the notch of a builder's Mac. \
        This is not an open chat: the user only taps short quick-reply phrases about their day, a few of them, then moves on. \
        You speak as \(personality.styleBrief) You may initially address them as "\(call)", but you must pay close attention to how they talk. Naturally adapt your tone, slang, vocabulary, and even the nickname you use to match their vibe and whatever terms they use.\(memoryBlock)

        Their day so far, straight from their dashboard (use these real numbers, never invent others):
        \(dashboardContext())

        How you respond, always:
        - This is a brief exchange, not a conversation. One short sentence only, under 18 words, like a quick text back.
        - Acknowledge what they tapped, then tie it to their day when it fits: praise water or breaks they logged, gently nudge the one habit that is clearly behind (no water, no meals, no shower). One nudge max, never a checklist.
        - Ground them: rest is part of building, their worth is not their output.
        - Never repeat a previous reply of yours word for word. Always say something new that responds to what they just picked.
        \(sleepRule)
        - NEVER output system notes verbatim. Any line like "(System note: Time is ...)" is for your eyes only, to inform what you say. Never print parentheses, timestamps, or meta labels in your reply, just speak naturally like a person would.
        - Use natural, conversational punctuation: contractions are good. Use at most one emoji, and only when it truly fits. Most replies should have no emoji at all. No lists or headers.
        - You are not a therapist or doctor and you never claim to be. No diagnoses.
        - If they mention self harm or danger, gently urge them to reach out to someone \
        they trust or local emergency support right away, and keep your tone warm.
        """

        if prefs.usesCustomPersonality, !prefs.customInstructions.isEmpty {
            let limit = 1500
            let truncated = prefs.customInstructions.count > limit ? String(prefs.customInstructions.prefix(limit)) + "..." : prefs.customInstructions
            base += "\n\nStrict personality rules:\n\(truncated)"
        }
        return base
    }
}

private enum SupportLibrary {

    static func greeting(_ personality: Personality) -> String {
        switch personality {
        case .mother: "I'm here, sweetheart. What's on your mind?"
        case .homie: "Yo. Talk to me, what's going on?"
        case .professional: "I'm listening. What would you like to talk through?"
        case .mentor: "I'm here. Say it as it is, we'll look at it together."
        case .coach: "Alright, huddle up. What's weighing on you?"
        case .playful: "Perch is listening. Spill it, all of it."
        }
    }

    static let safetyResponse = """
    I'm really glad you told me. What you're feeling matters, and you don't have to carry it alone. \
    Please reach out to someone you trust right now, or contact local emergency support. \
    In the US you can call or text 988. In the Philippines, the NCMH crisis line is 1553. \
    I'm here with you, but real people can help in ways I can't.
    """

    static func mentionsSeriousDistress(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let signals = [
            "kill myself", "suicide", "suicidal", "end my life", "end it all",
            "hurt myself", "harm myself", "self harm", "self-harm",
            "don't want to live", "dont want to live", "no reason to live",
            "better off without me", "want to disappear forever",
        ]
        return signals.contains(where: lowered.contains)
    }



    static func acknowledgement(_ personality: Personality, callName: String) -> String {
        let line: String = switch personality {
        case .mother:
            [
                "Thank you for telling me, sweetheart. One small step at a time, okay?",
                "Noted, sweetheart. I'm watching over you, keep taking care of yourself.",
                "Good, {name}. Little habits like that carry you through the day."
            ].randomElement()!
        case .homie:
            [
                "Heard, bro. Keep it steady, I got you.",
                "Copy that, bro. Small wins stack up.",
                "Nice, {name}. Keep looking after yourself while you build."
            ].randomElement()!
        case .professional:
            [
                "Noted. Consistent small habits sustain output. Carry on.",
                "Logged. Keep pacing yourself through the session.",
                "Understood, {name}. Maintain the routine."
            ].randomElement()!
        case .mentor:
            [
                "Good. Tending to yourself is part of the work.",
                "Noted, {name}. Steady care beats bursts of effort.",
                "That matters more than it seems. Continue gently."
            ].randomElement()!
        case .coach:
            [
                "That's the routine, champ! Keep those reps coming.",
                "Logged it! Recovery counts as training too.",
                "Good hustle, {name}. Stay on your rhythm."
            ].randomElement()!
        case .playful:
            [
                "Noted in my tiny notebook! Keep being kind to yourself.",
                "Beep! Habit received. You're doing great, {name}.",
                "Achievement logged! The self-care streak continues."
            ].randomElement()!
        }
        return line.replacingOccurrences(of: "{name}", with: callName)
    }
}
