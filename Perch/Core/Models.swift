import Foundation

// MARK: - Plans and feature gating

enum PlanTier: String, Codable, Comparable {
    case free
    case pro
    case premium

    private var rank: Int {
        switch self {
        case .free: 0
        case .pro: 1
        case .premium: 2
        }
    }

    static func < (lhs: PlanTier, rhs: PlanTier) -> Bool { lhs.rank < rhs.rank }

    var displayName: String {
        switch self {
        case .free: "Free"
        case .pro: "Pro"
        case .premium: "Premium"
        }
    }
}

struct FeatureGate {
    let tier: PlanTier

    var allPersonalities: Bool { tier >= .pro }
    var adaptiveMemory: Bool { tier >= .pro }

    var aiChat: Bool { true }
    var calendarAwareness: Bool { tier >= .pro }
    var voiceInteraction: Bool { tier >= .pro }
    var advancedQuickActions: Bool { tier >= .pro }
    var weeklySummary: Bool { tier >= .pro }
    var customPersonality: Bool { tier >= .premium }
    var voiceStyles: Bool { tier >= .premium }
    var maxRoutines: Int { tier == .free ? 3 : 20 }
}

// MARK: - Reminder model

enum ReminderKind: String, Codable, CaseIterable, Identifiable {
    case water
    case stretch
    case eyes
    case posture
    case walk
    case meal
    case shower
    case overwork
    case windDown
    case sleep
    case meetingPrep
    case meetingRecovery
    case routine
    case status
    case welcome
    case sessionStart

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .water: "Water"
        case .stretch: "Stretch"
        case .eyes: "Eye rest"
        case .posture: "Posture"
        case .walk: "Short walk"
        case .meal: "Meals"
        case .shower: "Shower"
        case .overwork: "Overwork check"
        case .windDown: "Wind down"
        case .sleep: "Sleep"
        case .meetingPrep: "Meeting prep"
        case .meetingRecovery: "Meeting recovery"
        case .routine: "Personal routine"
        case .status: "Check in"
        case .welcome: "Welcome"
        case .sessionStart: "Hello"
        }
    }

    var symbolName: String {
        switch self {
        case .water: "drop.fill"
        case .stretch: "figure.flexibility"
        case .eyes: "eye.fill"
        case .posture: "person.bust"
        case .walk: "figure.walk"
        case .meal: "fork.knife"
        case .shower: "shower.fill"
        case .overwork: "hourglass"
        case .windDown: "sunset.fill"
        case .sleep: "moon.stars.fill"
        case .meetingPrep: "calendar.badge.clock"
        case .meetingRecovery: "cup.and.saucer.fill"
        case .routine: "checklist"
        case .status: "sparkles"
        case .welcome: "sparkles"
        case .sessionStart: "sun.max.fill"
        }
    }

    static var togglable: [ReminderKind] {
        [.water, .stretch, .eyes, .posture, .walk, .meal, .shower, .overwork, .windDown, .sleep, .meetingPrep, .meetingRecovery]
    }

    var defaultEnabled: Bool {
        switch self {
        case .posture, .sleep: false
        default: true
        }
    }

    var requiresCalendar: Bool {
        self == .meetingPrep || self == .meetingRecovery
    }

    var supportsTimer: Bool {
        switch self {
        case .stretch, .eyes, .walk, .overwork: true
        default: false
        }
    }

    /// Timer length matching what the lines promise: twenty seconds of eye
    /// rest, a one minute stretch, a five minute walk or break.
    var timerSeconds: Int {
        switch self {
        case .eyes: 20
        case .stretch: 60
        case .walk, .overwork: 300
        default: 60
        }
    }

    var primaryActionLabel: String {
        switch self {
        case .water: "Drank some"
        case .stretch: "Stretched"
        case .eyes: "Rested eyes"
        case .walk: "Walked"
        case .shower: "Showered"
        case .overwork: "Stepping away"
        case .posture: "Fixed it"
        case .meal: "I ate"
        case .meetingPrep: "Ready"
        case .meetingRecovery: "Taking it"
        case .windDown: "On it"
        case .sleep: "Okay, goodnight"
        case .status, .welcome, .sessionStart: "All good"
        case .routine: "Done"
        }
    }

    /// Advice-style check ins earn a polite "Thanks" answer chip.
    var supportsThanks: Bool {
        switch self {
        case .overwork, .windDown, .sleep, .meetingPrep, .meetingRecovery: true
        default: false
        }
    }

    var priority: Int {
        switch self {
        case .meetingPrep: 100
        case .meal: 90
        case .shower: 65
        case .overwork: 85
        case .sleep: 80
        case .windDown: 75
        case .routine: 70
        case .walk: 60
        case .stretch: 55
        case .water: 50
        case .meetingRecovery: 45
        case .posture: 40
        case .eyes: 35
        case .sessionStart: 15
        case .status, .welcome: 10
        }
    }

    var isTrackable: Bool {
        self != .status && self != .welcome && self != .sessionStart
    }
}

// MARK: - Check ins

struct CheckInContext {
    var minutes: Int?
    var mealName: String?
    var eventTitle: String?
    var minutesUntil: Int?
    var yesterdaySkipped: Bool = false
    var routineLabel: String?
    var customMessage: String?

    static let empty = CheckInContext()
}

struct CheckIn: Identifiable {
    let id = UUID()
    let kind: ReminderKind
    let message: String
    let createdAt = Date()
    var context: CheckInContext = .empty

    @MainActor
    func computedTimerSeconds(prefs: PreferencesStore? = nil) -> Int {
        if kind == .walk || kind == .overwork {
            if let prefs = prefs {
                return prefs.timerDurationMinutes * 60
            }
            let focusMins = context.minutes ?? 0
            if focusMins > 90 {
                return 20 * 60 
            } else if focusMins > 60 {
                return 15 * 60 
            } else {
                return 10 * 60 
            }
        }
        return kind.timerSeconds
    }
}

enum CheckInResponse: Equatable {
    case done
    case snoozed(minutes: Int)
    case ignored
    case timedOut
    case timerCompleted

    var isPositive: Bool {
        switch self {
        case .done, .timerCompleted: true
        default: false
        }
    }
}

// MARK: - Time helpers

enum Daypart: String, Codable, CaseIterable {
    case morning
    case midday
    case afternoon
    case evening
    case night

    static func from(_ date: Date) -> Daypart {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 5..<11: return .morning
        case 11..<14: return .midday
        case 14..<18: return .afternoon
        case 18..<22: return .evening
        default: return .night
        }
    }

    var displayName: String {
        switch self {
        case .morning: "morning"
        case .midday: "midday"
        case .afternoon: "afternoon"
        case .evening: "evening"
        case .night: "late night"
        }
    }
}

func minutesOfDay(_ date: Date) -> Int {
    let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
    return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
}

func humanDuration(minutes: Int) -> String {
    if minutes < 50 {
        let value = max(minutes, 1)
        return value == 1 ? "1 minute" : "\(value) minutes"
    }
    let hours = minutes / 60
    let rem = minutes % 60
    if rem >= 45 {
        let next = hours + 1
        return next == 1 ? "almost an hour" : "almost \(next) hours"
    }
    if rem <= 15 {
        return hours == 1 ? "about an hour" : "about \(hours) hours"
    }
    if (25...35).contains(rem) {
        return hours == 1 ? "an hour and a half" : "\(hours) and a half hours"
    }
    return hours == 1 ? "over an hour" : "over \(hours) hours"
}

func shortDuration(seconds: Double) -> String {
    let total = Int(seconds)
    let hours = total / 3600
    let minutes = (total % 3600) / 60
    if hours > 0 { return "\(hours)h \(String(format: "%02d", minutes))m" }
    return "\(minutes)m"
}

private let dayKeyFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    return formatter
}()

func weekdayLetter(forDayKey key: String) -> String {
    guard let date = dayKeyFormatter.date(from: key) else { return "?" }
    let weekday = dayKeyFormatter.calendar.component(.weekday, from: date)
    return ["S", "M", "T", "W", "T", "F", "S"][weekday - 1]
}

func stripAIPrefix(from text: String, aiName: String) -> String {
    let escapedName = NSRegularExpression.escapedPattern(for: aiName)
    var cleaned = text.replacingOccurrences(
        of: "^(?:\\*+)?\(escapedName)(?:\\*+)?\\s*:?(?:\\*+)?\\s*:?\\s*",
        with: "",
        options: [.regularExpression, .caseInsensitive]
    )
    cleaned = cleaned.replacingOccurrences(of: "^:\\s*", with: "", options: .regularExpression)
    return cleaned
}

// MARK: - User defined routines

struct RoutineReminder: Codable, Identifiable, Hashable {
    var id = UUID()
    var label: String
    var minuteOfDay: Int
    var enabled = true
    var message: String?

    var trimmedMessage: String? {
        guard let message else { return nil }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

enum ReminderIntensity: String, Codable, CaseIterable, Identifiable {
    case relaxed
    case balanced
    case attentive

    var id: String { rawValue }

    var intervalMultiplier: Double {
        switch self {
        case .relaxed: 1.35
        case .balanced: 1.0
        case .attentive: 0.78
        }
    }

    var displayName: String {
        switch self {
        case .relaxed: "Relaxed"
        case .balanced: "Balanced"
        case .attentive: "Attentive"
        }
    }

    var blurb: String {
        switch self {
        case .relaxed: "Check on me occasionally"
        case .balanced: "Check on me at a natural pace"
        case .attentive: "Look after me closely"
        }
    }
}
