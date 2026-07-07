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

/// Single source of truth for what the current plan unlocks.
struct FeatureGate {
    let tier: PlanTier

    var allPersonalities: Bool { tier >= .pro }
    var adaptiveMemory: Bool { tier >= .pro }
    /// AI runs on free local intelligence, so every tier gets it.
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

    /// Kinds the user can toggle in settings.
    static var togglable: [ReminderKind] {
        [.water, .stretch, .eyes, .posture, .walk, .meal, .overwork, .windDown, .sleep, .meetingPrep, .meetingRecovery]
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

    /// A break timer makes sense for physical resets.
    var supportsTimer: Bool {
        switch self {
        case .stretch, .eyes, .walk, .overwork: true
        default: false
        }
    }

    var primaryActionLabel: String {
        switch self {
        case .water: "Logged"
        case .meal: "I ate"
        case .meetingPrep: "Ready"
        case .meetingRecovery: "Taking it"
        case .windDown, .sleep: "On it"
        case .status, .welcome, .sessionStart: "All good"
        default: "Done"
        }
    }

    /// Higher wins when several reminders are due at once.
    var priority: Int {
        switch self {
        case .meetingPrep: 100
        case .meal: 90
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
}

// MARK: - Check ins

struct CheckInContext {
    var minutes: Int?
    var mealName: String?
    var eventTitle: String?
    var minutesUntil: Int?
    var yesterdaySkipped: Bool = false
    var routineLabel: String?

    static let empty = CheckInContext()
}

struct CheckIn: Identifiable {
    let id = UUID()
    let kind: ReminderKind
    let message: String
    let createdAt = Date()
    var context: CheckInContext = .empty
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

/// Turns a raw minute count into warm, human phrasing like "almost 3 hours".
func humanDuration(minutes: Int) -> String {
    if minutes < 50 { return "\(max(minutes, 1)) minutes" }
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

// MARK: - User defined routines

struct RoutineReminder: Codable, Identifiable, Hashable {
    var id = UUID()
    var label: String
    var minuteOfDay: Int
    var enabled = true
}

enum ReminderIntensity: String, Codable, CaseIterable, Identifiable {
    case relaxed
    case balanced
    case attentive

    var id: String { rawValue }

    /// Multiplier applied to base reminder intervals. Higher means fewer check ins.
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
