import Foundation
import Observation

/// User settings, persisted to UserDefaults. Every property saves on change.
@MainActor
@Observable
final class PreferencesStore {
    @ObservationIgnored private let defaults = UserDefaults.standard
    @ObservationIgnored private var isLoading = true

    // MARK: Onboarding and identity

    var hasOnboarded: Bool { didSet { save(hasOnboarded, "hasOnboarded") } }
    var userName: String { didSet { save(userName, "userName") } }

    // MARK: Personality

    var personality: Personality { 
        didSet { 
            if let savedVoice = voiceOverrides[personality.rawValue] {
                voiceIdentifier = savedVoice
            }
            save(personality.rawValue, "personality") 
        } 
    }
    var usesCustomPersonality: Bool { didSet { save(usesCustomPersonality, "usesCustomPersonality") } }
    var customCompanionName: String { didSet { save(customCompanionName, "customCompanionName") } }
    var customBaseStyle: Personality { didSet { save(customBaseStyle.rawValue, "customBaseStyle") } }
    var customSignoff: String { didSet { save(customSignoff, "customSignoff") } }
    var customInstructions: String { didSet { save(customInstructions, "customInstructions") } }

    // MARK: Rhythm

    var workStartMinutes: Int { didSet { save(workStartMinutes, "workStartMinutes") } }
    var workEndMinutes: Int { didSet { save(workEndMinutes, "workEndMinutes") } }
    var lunchMinutes: Int { didSet { save(lunchMinutes, "lunchMinutes") } }
    var dinnerMinutes: Int { didSet { save(dinnerMinutes, "dinnerMinutes") } }
    var quietStartMinutes: Int { didSet { save(quietStartMinutes, "quietStartMinutes") } }
    var quietEndMinutes: Int { didSet { save(quietEndMinutes, "quietEndMinutes") } }

    // MARK: Care preferences

    var enabledKinds: Set<ReminderKind> {
        didSet { save(enabledKinds.map(\.rawValue).sorted(), "enabledKinds") }
    }
    var intensity: ReminderIntensity { didSet { save(intensity.rawValue, "intensity") } }
    var routines: [RoutineReminder] {
        didSet {
            if let data = try? JSONEncoder().encode(routines) { save(data, "routines") }
        }
    }

    // MARK: Voice and notifications

    var voiceEnabled: Bool { didSet { save(voiceEnabled, "voiceEnabled") } }
    var voiceOverrides: [String: String] { didSet { save(voiceOverrides, "voiceOverrides") } }
    var voiceIdentifier: String { 
        didSet { 
            voiceOverrides[personality.rawValue] = voiceIdentifier
            save(voiceIdentifier, "voiceIdentifier") 
        } 
    }
    var notificationsMirror: Bool { didSet { save(notificationsMirror, "notificationsMirror") } }

    // MARK: Quick answer shortcut

    var shortcutKeyCode: Int { didSet { save(shortcutKeyCode, "shortcutKeyCode") } }
    var shortcutModifiers: UInt { didSet { save(shortcutModifiers, "shortcutModifiers") } }
    var micShortcutKeyCode: Int { didSet { save(micShortcutKeyCode, "micShortcutKeyCode") } }
    var micShortcutModifiers: UInt { didSet { save(micShortcutModifiers, "micShortcutModifiers") } }

    // MARK: Runtime controls

    var pausedUntil: Date? { didSet { save(pausedUntil, "pausedUntil") } }
    var demoMode: Bool { didSet { save(demoMode, "demoMode") } }
    var onlineMode: Bool { didSet { save(onlineMode, "onlineMode") } }
    var customVoiceIdentifier: String { didSet { save(customVoiceIdentifier, "customVoiceIdentifier") } }

    var openAiApiKey: String { didSet { Keychain.save("openAiApiKey", string: openAiApiKey) } }
    var geminiApiKey: String { didSet { Keychain.save("geminiApiKey", string: geminiApiKey) } }
    var anthropicApiKey: String { didSet { Keychain.save("anthropicApiKey", string: anthropicApiKey) } }

    // MARK: Init

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
        lunchMinutes = defaults.object(forKey: "lunchMinutes") as? Int ?? 12 * 60 + 30
        dinnerMinutes = defaults.object(forKey: "dinnerMinutes") as? Int ?? 19 * 60
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
        micShortcutKeyCode = defaults.object(forKey: "micShortcutKeyCode") as? Int ?? 46
        micShortcutModifiers = defaults.object(forKey: "micShortcutModifiers") as? UInt ?? Self.defaultModifiers
        pausedUntil = defaults.object(forKey: "pausedUntil") as? Date
        demoMode = defaults.bool(forKey: "demoMode")
        onlineMode = defaults.bool(forKey: "onlineMode")
        customVoiceIdentifier = defaults.string(forKey: "customVoiceIdentifier") ?? ""

        openAiApiKey = Keychain.loadString("openAiApiKey") ?? ""
        geminiApiKey = Keychain.loadString("geminiApiKey") ?? ""
        anthropicApiKey = Keychain.loadString("anthropicApiKey") ?? ""

        isLoading = false
    }

    /// Control + Option, combined NSEvent.ModifierFlags raw value.
    static let defaultModifiers: UInt = (1 << 18) | (1 << 19)

    // MARK: Derived

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

    // MARK: Persistence

    private func save(_ value: Any?, _ key: String) {
        guard !isLoading else { return }
        if let value {
            defaults.set(value, forKey: key)
        } else {
            defaults.removeObject(forKey: key)
        }
    }
}
