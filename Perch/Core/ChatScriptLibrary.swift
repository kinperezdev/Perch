enum ChatTopic {
    case water
    case meal
    case breakTime
    case shower
}

enum ChatScriptLibrary {
    enum Mood: Equatable {
        case great
        case okay
        case stressed
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
        }
        return pick(variants, key: "moodShort.\(mood).\(personality.rawValue)")
            .replacingOccurrences(of: "{call}", with: callName)
    }
}
