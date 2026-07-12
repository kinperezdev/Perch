import Foundation

// MARK: - Chat topics

enum ChatTopic: String, Codable, CaseIterable {
    case water
    case meal
    case breakTime
    case shower
    case feeling
}

// MARK: - Prebuilt chat script

/// Every line the companion says in chat lives here, curated per personality.
/// No AI generation: questions, answers, and confirmations always match.
/// Each line has paraphrased variants, and the picker never repeats the same
/// wording twice in a row for the same situation.
enum ChatScriptLibrary {

    enum Mood: String, CaseIterable, Equatable {
        case great
        case okay
        case tired
        case stressed
        case heavy

        var chipLabel: String {
            switch self {
            case .great: "Doing great"
            case .okay: "Am okay"
            case .tired: "A bit tired"
            case .stressed: "Stressed out"
            case .heavy: "Feeling heavy"
            }
        }
    }

    @MainActor private static var lastPicks: [String: Int] = [:]

    @MainActor
    private static func pick(_ variants: [String], key: String) -> String {
        guard variants.count > 1 else { return variants[0] }
        var index = Int.random(in: 0..<variants.count)
        if index == lastPicks[key] { index = (index + 1) % variants.count }
        lastPicks[key] = index
        return variants[index]
    }

    // MARK: Questions (each invites a Yes / No / Later answer)

    @MainActor
    static func question(_ topic: ChatTopic, _ personality: Personality) -> String {
        let variants: [String] = switch (topic, personality) {
        case (.water, .mother): ["Have you had some water recently? Even a few sips count.",
                                 "Have you been sipping water while you work?"]
        case (.water, .homie): ["You been drinking water or nah?",
                                "Real quick, any water in the system yet?"]
        case (.water, .professional): ["Have you had water recently?",
                                       "Quick check: any water in the last hour or so?"]
        case (.water, .mentor): ["Have you had any water lately?",
                                 "Has water been part of this last stretch of work?"]
        case (.water, .coach): ["Hydration check! Had some water?",
                                "Water check, quick one: had a glass recently?"]
        case (.water, .playful): ["Any water made it into you yet?",
                                  "Hydration status: has any water been consumed?"]

        case (.meal, .mother): ["Have you eaten something real today?",
                                "Did you get a proper meal in yet?"]
        case (.meal, .homie): ["You eaten yet, or running on vibes?",
                               "Any real food yet, or just coffee?"]
        case (.meal, .professional): ["Have you had a proper meal yet?",
                                      "Has there been a real meal today?"]
        case (.meal, .mentor): ["Have you eaten a real meal today?",
                                "Has the body been fed today, not just the work?"]
        case (.meal, .coach): ["Fuel check! Eaten anything yet?",
                               "Nutrition check: any real food in the tank?"]
        case (.meal, .playful): ["Has food happened today?",
                                 "Any evidence of a meal occurring today?"]

        case (.breakTime, .mother): ["You've been at it a while. Have you taken a little break?",
                                     "It's been a long stretch. Did you step away at all?"]
        case (.breakTime, .homie): ["You've been locked in a minute. Taken a breather yet?",
                                    "Long grind session. Any breaks in there?"]
        case (.breakTime, .professional): ["It has been a long stretch. Have you taken a break?",
                                           "Extended session so far. Any real pause yet?"]
        case (.breakTime, .mentor): ["The session runs deep. Have you paused at all?",
                                     "A long stretch of focus. Has there been a moment of rest?"]
        case (.breakTime, .coach): ["Long set! Taken a recovery break yet?",
                                    "Big session! Any recovery reps in yet?"]
        case (.breakTime, .playful): ["You've been in the zone forever. Any breaks yet?",
                                      "Zone status: eternal. Has a break occurred?"]

        case (.shower, .mother): ["Have you had your shower today?",
                                  "Did you get your shower in yet?"]
        case (.shower, .homie): ["Vibe check: showered today?",
                                 "Fresh check: hit the shower yet?"]
        case (.shower, .professional): ["Have you showered today?",
                                        "Has the shower happened yet today?"]
        case (.shower, .mentor): ["And the daily reset: showered yet?",
                                  "One more ritual: has the shower happened yet?"]
        case (.shower, .coach): ["Reset check! Showered today?",
                                 "Locker room check: shower done?"]
        case (.shower, .playful): ["Hygiene quest: shower done yet?",
                                   "Shower quest status: complete or pending?"]

        case (.feeling, .mother): ["How are you feeling in there?",
                                   "How's your heart doing in there?"]
        case (.feeling, .homie): ["How you holding up in there?",
                                  "How we feeling, real talk?"]
        case (.feeling, .professional): ["How are you feeling about the session?",
                                         "How are you holding up so far?"]
        case (.feeling, .mentor): ["How is your energy holding?",
                                   "How does the pace feel right now?"]
        case (.feeling, .coach): ["How's the tank looking?",
                                  "Energy check: how are we doing?"]
        case (.feeling, .playful): ["Status report: how are we feeling?",
                                    "Mandatory vibe census: how are you?"]
        }
        return pick(variants, key: "question.\(topic.rawValue).\(personality.rawValue)")
    }

    // MARK: Yes / Did it (habit gets logged, so the reply says so truthfully)

    @MainActor
    static func praise(_ topic: ChatTopic, _ personality: Personality, callName: String) -> String {
        let variants: [String] = switch (topic, personality) {
        case (.water, .mother): ["Good, {call}. I logged that water for you. Little sips keep you going.",
                                 "That's my {call}. Water logged, keep sipping through the day."]
        case (.water, .homie): ["Say less, {call}. Water logged. Stay winning.",
                                "Hydrated and dangerous. Logged it, {call}."]
        case (.water, .professional): ["Noted, water logged. Hydration sustains focus.",
                                       "Water logged. Good discipline."]
        case (.water, .mentor): ["Good. Water logged. Small habits, long careers.",
                                 "Logged. The small things are the practice, {call}."]
        case (.water, .coach): ["Hydration rep counted, {call}! Water logged.",
                                "That's a rep, {call}! Water in the books."]
        case (.water, .playful): ["Splash! Water logged in my tiny notebook.",
                                  "Glug confirmed. Water officially logged."]

        case (.meal, .mother): ["That makes me happy, {call}. Meal logged. A fed builder is a strong builder.",
                                "Good, {call}. Meal logged, that settles my worrying for a bit."]
        case (.meal, .homie): ["There you go, {call}. Meal logged. Machine stays fed.",
                               "Fed and locked in. Meal logged, {call}."]
        case (.meal, .professional): ["Excellent. Meal logged. That will steady your afternoon.",
                                      "Meal logged. Energy accounted for."]
        case (.meal, .mentor): ["Good. Meal logged. Fuel is part of the work.",
                                "Logged. A fed mind thinks in full sentences, {call}."]
        case (.meal, .coach): ["Fuel secured, {call}! Meal logged.",
                               "Refueled! Meal counted, {call}."]
        case (.meal, .playful): ["Nom confirmed! Meal logged. Hangry crisis averted.",
                                 "Food has occurred! Logging this glorious meal."]

        case (.breakTime, .mother): ["Good, {call}. Break logged. Rest is never wasted.",
                                     "I'm glad, {call}. Break logged, you earned it."]
        case (.breakTime, .homie): ["Smart move, {call}. Break logged. Recovery is part of the grind.",
                                    "Break logged, {call}. Rest now, cook later."]
        case (.breakTime, .professional): ["Noted, break logged. Recovery protects output.",
                                           "Break logged. Good pacing."]
        case (.breakTime, .mentor): ["Good. Break logged. Rhythm beats endurance.",
                                     "Logged. Stepping away is part of the craft, {call}."]
        case (.breakTime, .coach): ["Recovery rep counted, {call}! Break logged.",
                                    "Break in the books, {call}! That's how pros train."]
        case (.breakTime, .playful): ["Break logged! Your brain says thank you.",
                                      "Recharge complete! Break duly recorded."]

        case (.shower, .mother): ["Lovely, {call}. Shower logged. Fresh and ready.",
                                  "Good, {call}. Shower logged, you'll feel brand new."]
        case (.shower, .homie): ["Fresh reset, {call}. Shower logged.",
                                 "Clean slate, {call}. Shower logged."]
        case (.shower, .professional): ["Noted, shower logged. A clean reset.",
                                        "Shower logged. Reset complete."]
        case (.shower, .mentor): ["Good. Shower logged. Small resets steady the day.",
                                  "Logged. A clear body helps a clear mind, {call}."]
        case (.shower, .coach): ["Reset complete, {call}! Shower logged.",
                                 "Fresh out the locker room, {call}! Logged."]
        case (.shower, .playful): ["Sparkling clean legend detected. Shower logged!",
                                   "Fresh legend status: confirmed. Shower logged."]

        case (.feeling, _): ["Noted."]
        }
        return pick(variants, key: "praise.\(topic.rawValue).\(personality.rawValue)")
            .replacingOccurrences(of: "{call}", with: callName)
    }

    // MARK: No (a gentle nudge to do it now)

    @MainActor
    static func nudge(_ topic: ChatTopic, _ personality: Personality, callName: String) -> String {
        let action: String = switch topic {
        case .water: "drink water"
        case .meal: "eat"
        case .breakTime: "take a break"
        case .shower: "shower"
        case .feeling: "take a slow breath"
        }
        return "to \(action) and not forget about it"
    }

    // MARK: Later

    @MainActor
    static func later(_ personality: Personality, callName: String) -> String {
        return "okay i will remind you later but this time please do it so"
    }

    // MARK: Feelings (fuller replies, used in chat bubbles)

    @MainActor
    static func moodReply(_ mood: Mood, _ personality: Personality, callName: String) -> String {
        let variants: [String] = switch (mood, personality) {
        case (.great, .mother): ["That makes me so happy, {call}. Keep going gently.",
                                 "Oh that's wonderful, {call}. Keep that glow going."]
        case (.great, .homie): ["Love that for you, {call}. Keep cooking.",
                                "That's the vibe, {call}. Ride the wave."]
        case (.great, .professional): ["Excellent. Keep the current pace.",
                                       "Very good. Sustain the rhythm you're in."]
        case (.great, .mentor): ["Good. Protect that rhythm, {call}.",
                                 "A good state is worth guarding, {call}. Stay with it."]
        case (.great, .coach): ["That's the energy, {call}! Ride it.",
                                "Peak form, {call}! Keep that momentum."]
        case (.great, .playful): ["Excellent news! The vibes are officially immaculate.",
                                  "Splendid! Filing this under 'great days'."]

        case (.okay, .mother): ["Okay is enough, {call}. Steady as you go, I'm right here.",
                                "Steady is good too, {call}. I'm keeping you company."]
        case (.okay, .homie): ["Steady is solid, {call}. Keep it cruising.",
                               "Okay works, {call}. We keep it moving."]
        case (.okay, .professional): ["Noted. Keep your pace sustainable.",
                                      "Understood. Steady output is still progress."]
        case (.okay, .mentor): ["Okay is honest, {call}. Steady beats spectacular.",
                                "Middle days build the long road, {call}."]
        case (.okay, .coach): ["Steady counts, {call}! Keep the rhythm, I've got the clock.",
                               "Okay is still in the game, {call}. Keep playing."]
        case (.okay, .playful): ["Okay is a perfectly respectable vibe. Onward, gently.",
                                 "Medium vibes acknowledged. Proceeding gently."]

        case (.tired, .mother): ["Then rest a little, {call}. Even five minutes helps.",
                                 "Listen to that tiredness, {call}. A short rest, please."]
        case (.tired, .homie): ["Then take five, {call}. The grind can wait.",
                                "Tired means break time, {call}. Five minutes, trust."]
        case (.tired, .professional): ["A short break is recommended. It will pay for itself.",
                                       "Fatigue noted. A brief pause now prevents a slump later."]
        case (.tired, .mentor): ["Tiredness is information, {call}. Take a short pause.",
                                 "The body is speaking, {call}. Give it five quiet minutes."]
        case (.tired, .coach): ["Recovery time, {call}! Five minutes, then back strong.",
                                "That's the signal, {call}: rest rep, right now."]
        case (.tired, .playful): ["Hero nap moment! Five minutes of nothing, doctor's orders.",
                                  "Battery low! Please connect to five minutes of rest."]

        case (.stressed, .mother): ["Breathe with me, {call}. One thing at a time, you're doing fine.",
                                    "Come back to one breath, {call}. Then just the next small thing."]
        case (.stressed, .homie): ["Deep breath, {call}. One thing at a time, you got this.",
                                   "Ease up, {call}. Shrink it to one next move."]
        case (.stressed, .professional): ["Understandable. Narrow it to one next step, the rest can queue.",
                                          "Noted. Choose the single next action and let the rest wait."]
        case (.stressed, .mentor): ["Stress means you care, {call}. Pick the one next step and let go of the rest.",
                                    "When it swells, shrink the task, {call}. One step."]
        case (.stressed, .coach): ["Timeout, {call}. Breathe, pick one play, run just that one.",
                                   "Reset, {call}. One play at a time wins games."]
        case (.stressed, .playful): ["Deploying emergency calm! Breathe in, breathe out. One tiny thing at a time.",
                                     "Stress detected! Activating tiny calm ray: breathe, then one small thing."]

        case (.heavy, .mother): ["I'm here, {call}. Be gentle with yourself today, and if it ever feels like too much, please reach out to someone you trust.",
                                 "I'm right here, {call}. Go slow today, and let someone you trust carry a little of it."]
        case (.heavy, .homie): ["I got you, {call}. Heavy days pass. If it gets too much, hit up someone you trust, okay?",
                                "Heavy is real, {call}. Move gentle today, and don't hold it solo."]
        case (.heavy, .professional): ["Thank you for saying so. Be kind to yourself today, and lean on someone you trust if it deepens.",
                                       "Understood. Lower the bar for today, and keep someone you trust close."]
        case (.heavy, .mentor): ["Heavy days are part of the long road, {call}. Carry it gently, and don't carry it alone.",
                                 "Some days weigh more, {call}. Walk slower, and walk with someone."]
        case (.heavy, .coach): ["Even champions have heavy days, {call}. Ease up today, and lean on your people.",
                                "Heavy day protocol, {call}: lighter reps, more support. Lean on your people."]
        case (.heavy, .playful): ["Sending my whole tiny heart. Go easy today, and keep your people close, okay?",
                                  "All my tiny warmth is yours. Small steps today, and keep good people nearby."]
        }
        return pick(variants, key: "mood.\(mood.rawValue).\(personality.rawValue)")
            .replacingOccurrences(of: "{call}", with: callName)
    }

    /// Short mood replies for the notch confirmation toast, which only has
    /// room for two lines. The chat uses the fuller moodReply lines instead.
    @MainActor
    static func moodConfirmation(_ mood: Mood, _ personality: Personality, callName: String) -> String {
        let variants: [String] = switch (mood, personality) {
        case (.great, .mother): ["That's what I love to hear, {call}.",
                                 "Wonderful, {call}. Keep going gently."]
        case (.great, .homie): ["Love it, {call}. Keep cooking.",
                                "That's the vibe, {call}."]
        case (.great, .professional): ["Excellent. Carry on.",
                                       "Very good. Keep the pace."]
        case (.great, .mentor): ["Good. Protect that rhythm, {call}.",
                                 "Stay with that state, {call}."]
        case (.great, .coach): ["That's the energy, {call}!",
                                "Peak form, {call}! Keep it up."]
        case (.great, .playful): ["Vibes: immaculate. Carry on.",
                                  "Filing under 'great days'. Onward!"]

        case (.okay, .mother): ["Okay is enough, {call}. I'm here.",
                                "Steady is good too, {call}."]
        case (.okay, .homie): ["Steady is solid, {call}.",
                               "Okay works. Keep it moving, {call}."]
        case (.okay, .professional): ["Noted. Keep a sustainable pace.",
                                      "Understood. Steady is progress."]
        case (.okay, .mentor): ["Steady beats spectacular, {call}.",
                                "Middle days build the road, {call}."]
        case (.okay, .coach): ["Steady counts, {call}. Keep the rhythm.",
                               "Still in the game, {call}. Keep playing."]
        case (.okay, .playful): ["Okay is a respectable vibe. Onward.",
                                 "Medium vibes logged. Proceeding gently."]

        case (.tired, .mother): ["Then rest a little, {call}. Five minutes.",
                                 "Listen to it, {call}. Short rest, please."]
        case (.tired, .homie): ["Take five, {call}. The grind can wait.",
                                "Tired means break time, {call}. Trust."]
        case (.tired, .professional): ["A short break is recommended.",
                                       "Fatigue noted. Pause briefly soon."]
        case (.tired, .mentor): ["Tiredness is information. Pause soon.",
                                 "The body is speaking, {call}. Rest a bit."]
        case (.tired, .coach): ["Recovery time, {call}! Five minutes.",
                                "That's the signal: rest rep, {call}."]
        case (.tired, .playful): ["Hero nap moment. Doctor's orders.",
                                  "Battery low! Connect to rest, please."]

        case (.stressed, .mother): ["Breathe, {call}. One thing at a time.",
                                    "One breath, then one small thing, {call}."]
        case (.stressed, .homie): ["Deep breath, {call}. One thing at a time.",
                                   "Ease up, {call}. One next move."]
        case (.stressed, .professional): ["Understood. Narrow it to one next step.",
                                          "Choose one next action. The rest waits."]
        case (.stressed, .mentor): ["Pick the one next step. Release the rest.",
                                    "Shrink the task, {call}. One step."]
        case (.stressed, .coach): ["Timeout, {call}. Breathe, run one play.",
                                   "Reset, {call}. One play at a time."]
        case (.stressed, .playful): ["Emergency calm deployed. Breathe.",
                                     "Tiny calm ray activated. One small thing."]

        case (.heavy, .mother): ["I'm here, {call}. Be gentle with yourself.",
                                 "Go slow today, {call}. I'm with you."]
        case (.heavy, .homie): ["I got you, {call}. Heavy days pass.",
                                "Move gentle today, {call}. Not solo."]
        case (.heavy, .professional): ["Be kind to yourself today.",
                                       "Lower the bar today. That's wise."]
        case (.heavy, .mentor): ["Carry it gently, {call}. Not alone.",
                                 "Walk slower today, {call}. With someone."]
        case (.heavy, .coach): ["Ease up today, {call}. Lean on your people.",
                                "Lighter reps today, {call}. More support."]
        case (.heavy, .playful): ["Sending my whole tiny heart. Go easy.",
                                  "Small steps today. Good people nearby."]
        }
        return pick(variants, key: "moodShort.\(mood.rawValue).\(personality.rawValue)")
            .replacingOccurrences(of: "{call}", with: callName)
    }

    // MARK: Wrap up and sign off

    @MainActor
    static func wrapUp(_ personality: Personality, callName: String) -> String {
        let variants: [String] = switch personality {
        case .mother: ["That's everything I was worried about, {call}. I'm right up here if you need me.",
                       "Everything's tended to, {call}. I'll be quietly proud up here."]
        case .homie: ["That's the whole checklist, {call}. I'm up here if you need me.",
                      "Checklist clean, {call}. Holler if you need me."]
        case .professional: ["That covers everything. I'll be here, out of the way.",
                             "All items covered. Resuming quiet watch."]
        case .mentor: ["All tended to. Back to the craft, {call}.",
                       "Everything in order. Return to the work, {call}."]
        case .coach: ["Checklist cleared, {call}! Back to the game.",
                      "Full sweep, {call}! Back to the field."]
        case .playful: ["All boxes ticked! Returning to my perch. Poke me anytime.",
                        "Checklist conquered! Resuming perch duties."]
        }
        return pick(variants, key: "wrap.\(personality.rawValue)")
            .replacingOccurrences(of: "{call}", with: callName)
    }

    @MainActor
    static func signoff(_ personality: Personality, callName: String) -> String {
        let variants: [String] = switch personality {
        case .mother: ["Okay, {call}. Back to it, I'm watching over you.",
                       "Go on then, {call}. I'll keep quiet watch."]
        case .homie: ["Cool cool. Locked in with you, {call}.",
                      "Say less. I'm on watch, {call}."]
        case .professional: ["Very well. Resuming quiet watch.",
                             "Understood. I'll stay out of the way."]
        case .mentor: ["Good. I'll keep the pace quietly, {call}.",
                       "Back to it then, {call}. I'll mind the rhythm."]
        case .coach: ["Roger that, {call}. I'll call the next break.",
                      "Back to the game, {call}. I've got the clock."]
        case .playful: ["Perch out! Not really, I'm always here.",
                        "Returning to statue mode. Watching, always watching."]
        }
        return pick(variants, key: "signoff.\(personality.rawValue)")
            .replacingOccurrences(of: "{call}", with: callName)
    }
}
