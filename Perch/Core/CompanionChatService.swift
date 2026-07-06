import Foundation
import FoundationModels
import Observation

/// Emotional support conversations. The user can share how they feel and
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

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored private let intelligence: CompanionIntelligence
    @ObservationIgnored private let brain: PerchBrain
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
        voice: VoiceService,
        gateProvider: @escaping () -> FeatureGate
    ) {
        self.prefs = prefs
        self.intelligence = intelligence
        self.brain = brain
        self.voice = voice
        self.gateProvider = gateProvider
        load()
        Task { [weak self] in
            _ = self?.preparedSession()
        }
    }

    private var personality: Personality {
        prefs.activePersonality
    }

    /// Opens the chat, injecting the greeting only when there's no prior history.
    func openIfNeeded() {
        guard messages.isEmpty else { return }
        let hour = Calendar.current.component(.hour, from: Date())
        let daypart = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
        let greeting = "Good \(daypart), \(personality.callName(userName: prefs.userName)). " + SupportLibrary.greeting(personality)
        messages.append(ChatMessage(isUser: false, text: greeting))
        updateSuggestions(for: greeting)
        scheduleSave()
    }

    /// Feeds a proactive check-in into the chat silently, so the AI knows what Perch just asked.
    func injectCheckIn(_ text: String) {
        if let last = messages.last, last.text == text, !last.isUser { return }
        messages.append(ChatMessage(isUser: false, text: text))
        currentEmotion = CompanionFaceView.FaceState.inferred(from: text, fallback: .idle)
        updateSuggestions(for: text)
        scheduleSave()
    }
    
    /// Silently adds a message to the chat history without triggering TTS or thinking states.
    func injectSilentMessage(isUser: Bool, text: String) {
        messages.append(ChatMessage(isUser: isUser, text: text))
        if !isUser {
            currentEmotion = CompanionFaceView.FaceState.inferred(from: text, fallback: .idle)
            updateSuggestions(for: text)
        }
        scheduleSave()
    }

    /// Wipes the current conversation and its saved file. An intentional user action.
    func clear() {
        messages = []
        session = nil
        sessionPersonality = nil
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    func send(_ rawText: String) {
        let text = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isThinking else { return }
        suggestionTask?.cancel()
        suggestions = []
        messages.append(ChatMessage(isUser: true, text: text))
        scheduleSave()
        Task { await respond(to: text) }
    }

    // MARK: Response pipeline

    private func respond(to text: String) async {
        if SupportLibrary.mentionsSeriousDistress(text) {
            deliver(SupportLibrary.safetyResponse)
            return
        }
        isThinking = true
        var reply: String? = nil
        if intelligence.isAvailable, gateProvider().aiChat {
            reply = await aiReply(to: text)
        }
        isThinking = false
        deliver(reply ?? SupportLibrary.response(for: text, personality: personality, callName: personality.callName(userName: prefs.userName)))
    }

    private func deliver(_ text: String) {
        messages.append(ChatMessage(isUser: false, text: text))
        currentEmotion = CompanionFaceView.FaceState.inferred(from: text, fallback: .idle)
        
        voice.speakIfAllowed(text)
        updateSuggestions(for: text)
        scheduleSave()
    }
    
    private func updateSuggestions(for aiText: String) {
        suggestionTask?.cancel()
        guard intelligence.isAvailable, gateProvider().aiChat else {
            suggestions = ["I'm doing great!", "Just taking a break.", "A bit stressed.", "Back to work."]
            return
        }
        
        let aiName = prefs.usesCustomPersonality && !prefs.customCompanionName.isEmpty ? prefs.customCompanionName : "Perch"
        let prompt = """
        The companion (\(aiName)) just said this to the user:
        "\(aiText)"
        
        Generate exactly 4 short, distinct, natural replies the user might click to respond.
        Each reply must be under 6 words.
        Separate them perfectly with the '|' character.
        Example: I'm feeling great|Just a bit tired|I need a break|Back to work
        """
        
        suggestionTask = Task { [weak self] in
            guard let self else { return }
            if let online = await self.intelligence.onlineChat(system: "You generate quick reply suggestions.", prompt: prompt) {
                if Task.isCancelled { return }
                let chips = online.split(separator: "|").map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
                if chips.count >= 2 {
                    self.suggestions = Array(chips.prefix(4))
                }
            }
        }
    }

    // MARK: Persistence

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
            var cleaned = online.trimmingCharacters(in: .whitespacesAndNewlines)
            cleaned = cleaned.replacingOccurrences(of: "^(?:\\*\\*)?\\*?\(aiName)\\*?(?:\\*\\*)?:\\s*", with: "", options: [.regularExpression, .caseInsensitive])
            cleaned = cleaned.replacingOccurrences(of: "^:\\s*", with: "", options: .regularExpression)
            return Self.clipped(cleaned)
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
                var cleaned = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
                cleaned = cleaned.replacingOccurrences(of: "^(?:\\*\\*)?\\*?\(aiName)\\*?(?:\\*\\*)?:\\s*", with: "", options: [.regularExpression, .caseInsensitive])
                cleaned = cleaned.replacingOccurrences(of: "^:\\s*", with: "", options: .regularExpression)
                cleaned = Self.clipped(cleaned)
                return cleaned.isEmpty ? nil : cleaned
            } catch {
                return nil
            }
        }
        return nil
    }

    /// Hard cap so replies never turn into paragraphs, whatever the model does.
    private static func clipped(_ text: String) -> String {
        guard text.count > 280 else { return text }
        let sentences = text.split(separator: ".", omittingEmptySubsequences: true)
        guard sentences.count > 2 else { return String(text.prefix(280)) }
        return sentences.prefix(2).joined(separator: ".") + "."
    }

    @ObservationIgnored private var sessionInstructions: String?

    private func preparedSession() -> LanguageModelSession {
        let currentInstructions = chatInstructions()
        if let session, sessionPersonality == personality, sessionInstructions == currentInstructions {
            return session
        }
        let fresh = LanguageModelSession(instructions: currentInstructions)
        fresh.prewarm()
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
        
        var base = """
        You are \(aiName), a small wellbeing companion who lives near the notch of a builder's Mac. \
        They open this chat to share feelings, stress, wins, doubts, or problems. \
        You speak as \(personality.styleBrief) You may initially address them as "\(call)", but you must pay close attention to how they talk. Naturally adapt your tone, slang, vocabulary, and even the nickname you use to match their vibe and whatever terms they use in conversation. Let your wordings evolve based on the chat.\(memoryBlock)

        How you respond, always:
        - Talk like a person texting a friend: short, warm, natural. One or two sentences, under 40 words.
        - Acknowledge the feeling first, then offer one small practical next step. Never lecture, never list.
        - Ground them: rest is part of building, their worth is not their output.
        - CRITICAL RULE: You will be given the current time. If it is past 10 PM or late at night AND they are still working or chatting, you MUST explicitly state the exact time and forcefully tell them to go to sleep. You must convey this exact meaning: "It's already [Time] and I know you are putting some work in today, but I want you to keep yourself healthy because your health is important to me and for your future. Now go to sleep, okay? Goodnight \(call)." You MUST phrase this firmly but adapt the words to perfectly match your specific personality! HOWEVER, if they are already saying goodnight or agreeing to sleep, do NOT repeat the warning. Just warmly say goodnight back and let them rest!
        - Use highly expressive texting punctuation! Emphasize words with exclamation marks (!), use question marks (?), trailing ellipses (...) to sound conversational, and feel free to use emojis if they fit the vibe. No lists or headers.
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

// MARK: - Curated support responses

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

    enum Bucket {
        case tired, unseen, afraid, stuck, win, general
    }

    static func classify(_ text: String) -> Bucket {
        let lowered = text.lowercased()
        let tired = ["tired", "exhaust", "burn", "burned out", "burnt", "drained", "no energy", "sleepy", "can't anymore"]
        let unseen = ["no one sees", "nobody", "no reaction", "ignored", "no users", "no likes", "crickets", "nobody cares", "invisible"]
        let afraid = ["scared", "afraid", "wasting", "waste of time", "fail", "behind", "not good enough", "doubt", "imposter", "anxious"]
        let stuck = ["don't know what", "dont know what", "stuck", "focus on next", "lost", "overwhelmed", "too much", "where to start"]
        let win = ["shipped", "launched", "finished", "i did it", "finally done", "released", "won"]
        if tired.contains(where: lowered.contains) { return .tired }
        if unseen.contains(where: lowered.contains) { return .unseen }
        if afraid.contains(where: lowered.contains) { return .afraid }
        if stuck.contains(where: lowered.contains) { return .stuck }
        if win.contains(where: lowered.contains) { return .win }
        return .general
    }

    static func response(for text: String, personality: Personality, callName: String) -> String {
        let line: String = switch (classify(text), personality) {
        case (.tired, .mother):
            [
                "Sweetheart, I know you want to finish everything, but your body needs you too. Rest for 10 minutes, drink water, then return with a clearer mind.",
                "You've been working so hard, sweetheart. Please close your eyes for just five minutes.",
                "It's okay to put it down for tonight. Your wellbeing matters more than this project."
            ].randomElement()!
        case (.tired, .homie):
            [
                "Bro, I get it. You're locked in, but don't punish yourself. Take a breather first. You're still building even when you rest.",
                "Your brain is fried, bro. Step away for ten minutes. The code isn't going anywhere.",
                "Homie, you're running on empty. Grab some water and touch some grass for a sec, then come back."
            ].randomElement()!
        case (.tired, .professional):
            [
                "You seem mentally overloaded. I recommend reducing your next task into one small action. Finish one step, then reassess.",
                "Fatigue diminishes output quality. Step away for 15 minutes before continuing.",
                "I suggest taking a structured break. You can resume with sharper focus afterward."
            ].randomElement()!
        case (.tired, .mentor):
            [
                "Tiredness is information, not weakness. Step away for ten minutes. The work will meet you again, and you will be sharper for it.",
                "Even the best builders must rest. Step back and let your subconscious solve the problem.",
                "Do not force it when the mind is dull. Rest is part of the process, not an interruption."
            ].randomElement()!
        case (.tired, .coach):
            [
                "Heavy legs mean it's recovery time, champ. Ten minute reset: water, air, shoulders down. Then we decide what's actually next.",
                "Take a timeout! Hydrate and shake it off. You'll come back swinging.",
                "Rest is training too, champ! Don't overtrain. Take five and regroup."
            ].randomElement()!
        case (.tired, .playful):
            [
                "Your battery icon is doing the sad red thing. Tiny nap for your brain: ten minutes away from the screen. I'll guard the keyboard.",
                "Error 404: Energy not found. Please insert coffee or take a nap!",
                "You're running on fumes and dreams! Go rest before you type something silly."
            ].randomElement()!

        case (.unseen, .mother):
            [
                "Sweetheart, I see what you're building, even when the internet is quiet. Good things grow slowly. Keep going, and eat something while you wait.",
                "I know it feels lonely right now, but I'm so proud of you. Your time will come.",
                "Don't worry about the noise. Keep making beautiful things, sweetheart."
            ].randomElement()!
        case (.unseen, .homie):
            [
                "Crickets don't mean it's bad, bro. Every big thing started unseen. Ship the next piece, the right people find you eventually.",
                "Don't let the silence get to you, bro. You're laying bricks. One day it's a house.",
                "Bro, the algorithm is weird. Keep your head down and keep building. Your time will come."
            ].randomElement()!
        case (.unseen, .professional):
            [
                "Low visibility now does not measure the work's value. Consistency compounds. One suggestion: share one small piece of progress this week.",
                "Metrics fluctuate. Focus on the core product quality instead of immediate reactions.",
                "The initial launch phase is often quiet. Maintain your release schedule."
            ].randomElement()!
        case (.unseen, .mentor):
            [
                "Being unseen is part of every builder's early chapters. Build for the work itself first. Attention follows patience more often than noise.",
                "Do not let the silence deter you. The foundation is poured in the dark.",
                "Your true audience will find you when you are ready. Keep honing your craft."
            ].randomElement()!
        case (.unseen, .coach):
            [
                "Empty stands, same effort. That's what pros do. Play the long season, {name}. The crowd shows up after the reps are in.",
                "Head down, keep grinding! The scoreboard will catch up eventually.",
                "You don't play for the cheers, champ! You play to win. Keep pushing!"
            ].randomElement()!
        case (.unseen, .playful):
            [
                "Plot twist: every legend has a montage where nobody's watching. You're in it right now. Keep building, future fans are on their way.",
                "The internet is just asleep! Leave them a masterpiece to wake up to.",
                "I'm your number one fan! The rest of them are just running late to the party."
            ].randomElement()!

        case (.afraid, .mother):
            [
                "Sweetheart, fear means you care. You are not wasting your time when you are learning and building. One step today is enough. I'm proud of you already.",
                "It's completely normal to feel scared. Just take my hand and let's do the next tiny thing together.",
                "You are stronger than your doubts, sweetheart. I believe in you."
            ].randomElement()!
        case (.afraid, .homie):
            [
                "That fear hits everyone who's building something real, bro. You're not behind, you're on your own clock. Just take the next small step.",
                "Imposter syndrome is a liar, bro. You got this. Just focus on the very next tiny task.",
                "Bro, everyone's scared when they're making something new. Don't sweat it. Just write one more line."
            ].randomElement()!
        case (.afraid, .professional):
            [
                "Uncertainty is normal in ambitious work. Reduce the question: what is one concrete step you can verify this week? Start there.",
                "Risk is inherent. Mitigate it by breaking the project into smaller, testable milestones.",
                "Focus on the data, not the doubt. Execute the next immediate objective."
            ].randomElement()!
        case (.afraid, .mentor):
            [
                "You do not need to solve everything tonight. Choose the next right step. Protect your energy.",
                "Fear is just a shadow cast by the importance of your work. Step into the light and begin.",
                "Doubt is part of the journey. Acknowledge it, and then proceed anyway."
            ].randomElement()!
        case (.afraid, .coach):
            [
                "Doubt shows up right before growth, champ. Shrink the game: one drill, one rep, today. Confidence is built, not found.",
                "Shake off the nerves! Get back to basics and run the play.",
                "Fear is just fuel, champ! Let's burn it and get moving!"
            ].randomElement()!
        case (.afraid, .playful):
            [
                "Scary thoughts get smaller when you feed them tiny wins. Pick one ridiculous small task and beat it. Fear hates that trick.",
                "Boo! Did I scare the fear away? No? Okay, let's just do a tiny baby step instead.",
                "If we hide under a blanket, the bugs can't get us. Or we can just squash them one by one!"
            ].randomElement()!

        case (.stuck, .mother):
            [
                "It's okay to not know, sweetheart. Rest first, then write down the three things pulling at you. Pick the one that helps people most. One step at a time.",
                "Take a deep breath. You don't have to figure it all out right this second.",
                "Why don't we step away for a bit? The answer will come to you, sweetheart."
            ].randomElement()!
        case (.stuck, .homie):
            [
                "When everything's loud, pick the smallest thing that moves the needle, bro. One thing. Momentum beats strategy when you're stuck.",
                "Bro, break it down. What's the absolute dumbest, easiest next step? Do that.",
                "You're overthinking it, homie. Just pick one tiny thing and crush it to get the momentum back."
            ].randomElement()!
        case (.stuck, .professional):
            [
                "Overwhelm usually means the next step is undefined. Write down the options, pick one for the next hour only, and begin. Clarity follows action.",
                "Let's untangle this. What is the single highest priority right now? Execute that exclusively.",
                "When blocked, try changing your environment or documenting the problem. Solutions often emerge in the process."
            ].randomElement()!
        case (.stuck, .mentor):
            [
                "You don't need the whole path, only the next stone. What matters most if this week went well? Start there, gently.",
                "A blocked river eventually finds a new way. Step back and look at the landscape.",
                "Sometimes the obstacle is the way. What is this problem trying to teach you?"
            ].randomElement()!
        case (.stuck, .coach):
            [
                "Too many plays on the board, champ. Call one. Run it for 25 minutes. We review after, that's how games get unstuck.",
                "Stop staring at the wall and start climbing! Take one small step.",
                "Focus! Cancel the noise and tackle the immediate target."
            ].randomElement()!
        case (.stuck, .playful):
            [
                "Brain traffic jam detected. Emergency protocol: pick the task with the funniest name and do it first. Motion beats meditation on this one.",
                "Did you try turning it off and on again? Seriously, go take a walk!",
                "I've dispatched a tiny search party to find your motivation. While we wait, just type a comment!"
            ].randomElement()!

        case (.win, .mother):
            [
                "Sweetheart! I'm so proud of you. Celebrate it properly, okay? Eat something good tonight. The reaction will come, the work is already real.",
                "Oh my goodness, well done! You worked so hard on this. Please rest now.",
                "That's wonderful news! I knew you could do it, sweetheart."
            ].randomElement()!
        case (.win, .homie):
            [
                "LET'S GO. You shipped, that already puts you ahead of everyone who didn't. Reactions lag, bro. Celebrate tonight, iterate tomorrow.",
                "Huge W, bro! I'm hype for you. Take the night off and play some games, you earned it.",
                "Bro!! That's massive. Remember this feeling, it's what you build for."
            ].randomElement()!
        case (.win, .professional):
            [
                "Shipping is the hard part and you did it. Reception often trails release. Log the win, rest tonight, and plan one follow up touchpoint.",
                "Excellent work. Take a moment to record this milestone before moving to the next objective.",
                "Target achieved. I recommend concluding operations for the day to rest."
            ].randomElement()!
        case (.win, .mentor):
            [
                "You finished something real. Let that land before you measure it. The world reacts on its own schedule; your job today is to acknowledge the work.",
                "A milestone reached is a moment to pause. Savor the accomplishment.",
                "Well done. The journey continues, but today you have reached a summit."
            ].randomElement()!
        case (.win, .coach):
            [
                "That's a W, champ! Wins count even when the crowd is quiet. Take the victory lap: rest tonight, review tomorrow, next play after.",
                "Great hustle out there! Celebrate the win, you earned every bit of it.",
                "Boom! That's how we execute! Enjoy the victory, champ."
            ].randomElement()!
        case (.win, .playful):
            [
                "Confetti! You shipped a real thing into the real world. Silence after launch is just the universe buffering. Celebrate anyway.",
                "Victory dance protocol initiated! Beep boop! Do a little spin!",
                "Huzzah! You did the thing! I've baked you a virtual cake."
            ].randomElement()!

        case (.general, .mother):
            [
                "Thank you for telling me, sweetheart. Whatever it is, we take it one small step at a time. Drink water first, then tell me more if you want.",
                "I'm always here to listen, sweetheart. Talk to me.",
                "You're safe here. Tell me what's on your mind."
            ].randomElement()!
        case (.general, .homie):
            [
                "I hear you, bro. For real. Whatever's going on, you don't have to figure it all out tonight. What's the one thing bugging you most?",
                "That's heavy, bro. Take a deep breath. We'll figure this out together.",
                "Bro, I'm here for you. Don't stress too much right now. What's the next small move?"
            ].randomElement()!
        case (.general, .professional):
            [
                "Understood. Let's make it manageable: name the single biggest concern, and we'll shape one next step around it.",
                "I am here to assist. Let's break this down logically.",
                "Acknowledged. How can we proceed to resolve this effectively?"
            ].randomElement()!
        case (.general, .mentor):
            [
                "I'm listening. Feelings like this usually point at something that matters. Say more if you wish, or simply rest with it for now.",
                "Take your time. I am here whenever you are ready to explore this.",
                "This is a safe space to reflect. What is truly bothering you?"
            ].randomElement()!
        case (.general, .coach):
            [
                "Heard, champ. Every athlete has heavy days. Talk it out or take a reset lap, both count as training.",
                "I've got your back. Let's huddle up and figure out a play.",
                "Keep your head up! What's the block right now?"
            ].randomElement()!
        case (.general, .playful):
            [
                "Received and taken seriously, despite my whimsical exterior. Want to tell me more, or should I deploy emergency encouragement?",
                "I'm all ears! Well, metaphorical ears. What's going on?",
                "Scanning for solutions... In the meantime, I'm here to listen!"
            ].randomElement()!
        }
        return line.replacingOccurrences(of: "{name}", with: callName)
    }
}
