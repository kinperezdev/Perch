import SwiftUI
import Observation

// MARK: - Personality

enum Personality: String, Codable, CaseIterable, Identifiable {
    case mother
    case homie
    case professional
    case mentor
    case coach
    case playful

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .mother: "Mom"
        case .homie: "Homie"
        case .professional: "Assistant"
        case .mentor: "Mentor"
        case .coach: "Coach"
        case .playful: "Spark"
        }
    }

    var tagline: String {
        switch self {
        case .mother: "Warm, caring, will make you eat"
        case .homie: "Your ride or die in the trenches"
        case .professional: "Precise, respectful, reliable"
        case .mentor: "Calm wisdom, long game thinking"
        case .coach: "Energy, momentum, recovery reps"
        case .playful: "A little chaos, a lot of care"
        }
    }

    var symbolName: String {
        switch self {
        case .mother: "heart.fill"
        case .homie: "hand.wave.fill"
        case .professional: "briefcase.fill"
        case .mentor: "leaf.fill"
        case .coach: "bolt.fill"
        case .playful: "sparkles"
        }
    }

    var accentColors: [Color] {
        switch self {
        case .mother: [Color(hex: 0xFF8FA3), Color(hex: 0xFFC29E)]
        case .homie: [Color(hex: 0x9BE15D), Color(hex: 0x00E3AE)]
        case .professional: [Color(hex: 0x7BA7FF), Color(hex: 0x88E0FF)]
        case .mentor: [Color(hex: 0x63C58F), Color(hex: 0x9BE8C3)]
        case .coach: [Color(hex: 0xFF6B35), Color(hex: 0xFFC53D)]
        case .playful: [Color(hex: 0xB57BFF), Color(hex: 0x6BC7FF)]
        }
    }


    var requiresPro: Bool {
        switch self {
        case .professional, .homie: false
        default: true
        }
    }


    func callName(userName: String) -> String {
        switch self {
        case .mother: return "sweetheart"
        case .homie: return "bro"
        case .coach: return "champ"
        default: return userName.isEmpty ? "friend" : userName
        }
    }


    var styleBrief: String {
        switch self {
        case .mother:
            "a loving mother figure. Warm, gently insistent, uses 'sweetheart' to address them. Caring, never guilt tripping."
        case .homie:
            "their best friend from the group chat. Casual, loyal, says 'bro', hype but genuinely caring. Slang is fine."
        case .professional:
            "a calm executive assistant. Concise, courteous, zero fluff, quietly supportive."
        case .mentor:
            "a wise, calm mentor. Speaks softly about the long game, sustainable pace, and craft."
        case .coach:
            "an upbeat athletic coach. Treats rest as training. Short punchy encouragement, never shouty."
        case .playful:
            "a whimsical little companion. Light, silly, kind. Tiny jokes are welcome, care always lands first."
        }
    }
}

// MARK: - Engine


@MainActor
final class PersonalityEngine {
    private let prefs: PreferencesStore
    private let intelligence: CompanionIntelligence
    private var lastVariantIndex: [String: Int] = [:]

    init(prefs: PreferencesStore, intelligence: CompanionIntelligence) {
        self.prefs = prefs
        self.intelligence = intelligence
    }

    var activePersonality: Personality {
        prefs.activePersonality
    }

    var companionName: String {
        prefs.usesCustomPersonality && !prefs.customCompanionName.isEmpty
            ? prefs.customCompanionName
            : "Perch"
    }


    func templateLine(for kind: ReminderKind, context: CheckInContext) -> String {
        if let custom = customLine(context: context) { return custom }
        let personality = activePersonality
        let variants = MessageLibrary.variants(kind: kind, personality: personality)
        guard !variants.isEmpty else { return "Time for a quick check in." }
        let index = pickIndex(count: variants.count, key: "\(personality.rawValue)|\(kind.rawValue)")
        return fill(variants[index], context: context)
    }


    func composeLine(for kind: ReminderKind, context: CheckInContext, aiAllowed: Bool, brainContext: String = "") async -> String {
        // The user's own words are sacred: never let the model rephrase them.
        if let custom = customLine(context: context) { return custom }
        let fallback = templateLine(for: kind, context: context)
        guard aiAllowed else { return fallback }
        var line = await intelligence.compose(
            kind: kind,
            personality: activePersonality,
            context: context,
            callName: activePersonality.callName(userName: prefs.userName),
            brainContext: brainContext,
            customInstructions: prefs.usesCustomPersonality ? prefs.customInstructions : "",
            fallback: fallback
        )
        if prefs.usesCustomPersonality, !prefs.customSignoff.isEmpty, Bool.random() {
            line += " \(prefs.customSignoff)"
        }
        return line
    }

    func confirmation(for response: CheckInResponse) -> String {
        let personality = activePersonality
        let variants = MessageLibrary.confirmations(response: response, personality: personality)
        guard !variants.isEmpty else { return "Noted." }
        let index = pickIndex(count: variants.count, key: "\(personality.rawValue)|confirm")
        return fill(variants[index], context: .empty)
    }

    func sampleLine(for personality: Personality) -> String {
        MessageLibrary.sample(personality: personality)
    }

        // MARK: Private

    private func customLine(context: CheckInContext) -> String? {
        guard let custom = context.customMessage, !custom.isEmpty else { return nil }
        let call = activePersonality.callName(userName: prefs.userName)
        return custom.replacingOccurrences(of: "{name}", with: call)
    }

    private func pickIndex(count: Int, key: String) -> Int {
        guard count > 1 else { return 0 }
        var index = Int.random(in: 0..<count)
        if index == lastVariantIndex[key] { index = (index + 1) % count }
        lastVariantIndex[key] = index
        return index
    }

    private func fill(_ template: String, context: CheckInContext) -> String {
        let call = activePersonality.callName(userName: prefs.userName)
        var line = template
        line = line.replacingOccurrences(of: "{name}", with: call)
        line = line.replacingOccurrences(of: "{duration}", with: humanDuration(minutes: context.minutes ?? 0))
        line = line.replacingOccurrences(of: "{meal}", with: context.mealName ?? "a meal")
        line = line.replacingOccurrences(of: "{event}", with: context.eventTitle ?? "your meeting")
        line = line.replacingOccurrences(of: "{mins}", with: String(context.minutesUntil ?? 0))
        line = line.replacingOccurrences(of: "{routine}", with: context.routineLabel ?? "your routine")
        return line
    }
}
