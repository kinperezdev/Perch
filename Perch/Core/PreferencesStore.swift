import Foundation
import Observation
@MainActor
@Observable
final class PreferencesStore {
    @ObservationIgnored private let defaults = UserDefaults.standard

    var hasOnboarded: Bool { didSet { save(hasOnboarded, "hasOnboarded") } }
    var userName: String { didSet { save(userName, "userName") } }

    var personality: Personality {
        didSet {
            if let savedVoice = voiceOverrides[personality.rawValue] {
                voiceIdentifier = savedVoice
            }
            save(personality.rawValue, "personality")
        }
    }
    var activePersonality: Personality {
        usesCustomPersonality ? customBaseStyle : personality
    }
    var usesCustomPersonality: Bool { didSet { save(usesCustomPersonality, "usesCustomPersonality") } }
    var customCompanionName: String { didSet { save(customCompanionName, "customCompanionName") } }
    var customBaseStyle: Personality { didSet { save(customBaseStyle.rawValue, "customBaseStyle") } }
    var customSignoff: String { didSet { save(customSignoff, "customSignoff") } }
    var customInstructions: String { didSet { save(customInstructions, "customInstructions") } }

    var workStartMinutes: Int { didSet { save(workStartMinutes, "workStartMinutes") } }
    var workEndMinutes: Int { didSet { save(workEndMinutes, "workEndMinutes") } }
    var breakfastMinutes: Int { didSet { save(breakfastMinutes, "breakfastMinutes") } }
    var lunchMinutes: Int { didSet { save(lunchMinutes, "lunchMinutes") } }
    var dinnerMinutes: Int { didSet { save(dinnerMinutes, "dinnerMinutes") } }
    var showerMinutes: Int { didSet { save(showerMinutes, "showerMinutes") } }
    var quietStartMinutes: Int { didSet { save(quietStartMinutes, "quietStartMinutes") } }
    var quietEndMinutes: Int { didSet { save(quietEndMinutes, "quietEndMinutes") } }

    var enabledKinds: Set<ReminderKind> {
        didSet { save(enabledKinds.map(\.rawValue).sorted(), "enabledKinds") }
    }
    var intensity: ReminderIntensity { didSet { save(intensity.rawValue, "intensity") } }
    var routines: [RoutineReminder] {
        didSet {
            if let data = try? JSONEncoder().encode(routines) { save(data, "routines") }
        }
    }

    var voiceEnabled: Bool { didSet { save(voiceEnabled, "voiceEnabled") } }
    var voiceOverrides: [String: String] { didSet { save(voiceOverrides, "voiceOverrides") } }
    var voiceIdentifier: String {
        didSet {
            voiceOverrides[personality.rawValue] = voiceIdentifier
            save(voiceIdentifier, "voiceIdentifier")
        }
    }
    var notificationsMirror: Bool { didSet { save(notificationsMirror, "notificationsMirror") } }

    var shortcutKeyCode: Int { didSet { save(shortcutKeyCode, "shortcutKeyCode") } }
    var shortcutModifiers: UInt { didSet { save(shortcutModifiers, "shortcutModifiers") } }

    var pausedUntil: Date? { didSet { save(pausedUntil, "pausedUntil") } }
    var demoMode: Bool { didSet { save(demoMode, "demoMode") } }

    init() {
        hasOnboarded = defaults.bool(forKey: "hasOnboarded")
        userName = defaults.string(forKey: "userName") ?? ""
        personality = Personality(rawValue: defaults.string(forKey: "personality") ?? "") ?? .professional
        usesCustomPersonality = defaults.bool(forKey: "usesCustomPersonality")
        customCompanionName = defaults.string(forKey: "customCompanionName") ?? "Perch"
        customBaseStyle = Personality(rawValue: defaults.string(forKey: "customBaseStyle") ?? "") ?? .mentor
        customSignoff = defaults.string(forKey: "customSignoff") ?? ""
        customInstructions = defaults.string(forKey: "customInstructions") ?? "I am a casual bro/homie. Be supportive but direct. Use casual slang."

        workStartMinutes = defaults.object(forKey: "workStartMinutes") as? Int ?? 9 * 60
        workEndMinutes = defaults.object(forKey: "workEndMinutes") as? Int ?? 18 * 60
        breakfastMinutes = defaults.object(forKey: "breakfastMinutes") as? Int ?? 7 * 60 + 30
        lunchMinutes = defaults.object(forKey: "lunchMinutes") as? Int ?? 12 * 60 + 30
        dinnerMinutes = defaults.object(forKey: "dinnerMinutes") as? Int ?? 19 * 60
        showerMinutes = defaults.object(forKey: "showerMinutes") as? Int ?? 8 * 60
        quietStartMinutes = defaults.object(forKey: "quietStartMinutes") as? Int ?? 22 * 60
        quietEndMinutes = defaults.object(forKey: "quietEndMinutes") as? Int ?? 8 * 60

        if let raw = defaults.stringArray(forKey: "enabledKinds") {
            enabledKinds = Set(raw.compactMap(ReminderKind.init(rawValue:)))
        } else {
            enabledKinds = Set(ReminderKind.togglable.filter(\.defaultEnabled))
        }
        intensity = ReminderIntensity(rawValue: defaults.string(forKey: "intensity") ?? "") ?? .balanced
        if let data = defaults.data(forKey: "routines"),
           let decoded = try? JSONDecoder().decode([RoutineReminder].self, from: data) {
            routines = decoded
        } else {
            routines = []
        }

        voiceEnabled = defaults.object(forKey: "voiceEnabled") as? Bool ?? false
        voiceOverrides = defaults.dictionary(forKey: "voiceOverrides") as? [String: String] ?? [:]
        voiceIdentifier = defaults.string(forKey: "voiceIdentifier") ?? ""
        notificationsMirror = defaults.object(forKey: "notificationsMirror") as? Bool ?? false

        shortcutKeyCode = defaults.object(forKey: "shortcutKeyCode") as? Int ?? 49
        shortcutModifiers = defaults.object(forKey: "shortcutModifiers") as? UInt ?? Self.defaultModifiers
        pausedUntil = defaults.object(forKey: "pausedUntil") as? Date
        demoMode = defaults.bool(forKey: "demoMode")
    }
    static let defaultModifiers: UInt = (1 << 18) | (1 << 19)

    var demoTimeScale: Double { demoMode ? 60 : 1 }

    func isPaused(at date: Date = Date()) -> Bool {
        guard let until = pausedUntil else { return false }
        return date < until
    }

    func isQuietHours(at date: Date = Date()) -> Bool {
        let minute = minutesOfDay(date)
        if quietStartMinutes == quietEndMinutes { return false }
        if quietStartMinutes < quietEndMinutes {
            return minute >= quietStartMinutes && minute < quietEndMinutes
        }
        return minute >= quietStartMinutes || minute < quietEndMinutes
    }

    func isAfterWorkHours(at date: Date = Date()) -> Bool {
        minutesOfDay(date) >= workEndMinutes
    }

    private func save(_ value: Any?, _ key: String) {
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
