import Foundation
import Observation

/// Perch's long-term memory. Learns from every interaction, persists to a
@MainActor
@Observable
final class PerchBrain {

    // MARK: - Data model

    struct Brain: Codable {
        /// The user's name, confirmed at onboarding.
        var userName: String = ""

        /// Anything the user has told Perch about themselves directly.
        var userNotes: [String] = []

        /// Peak observed focus hours. Key = hour-of-day (0-23), value = avg active seconds.
        var peakHours: [Int: Double] = [:]

        /// Kinds the user consistently accepts (acceptance rate > 0.7 over 10+ samples).
        var respondedWellTo: [String] = []

        /// Kinds the user consistently ignores (ignore rate > 0.7 over 10+ samples).
        var tendsToIgnore: [String] = []

        /// The user's longest ever recorded focus session in seconds.
        var longestFocusSession: Double = 0

        /// Total lifetime water logs.
        var lifetimeWaterLogs: Int = 0

        /// Total lifetime breaks taken.
        var lifetimeBreaks: Int = 0

        /// Total check ins Perch has delivered across all time.
        var lifetimeCheckIns: Int = 0

        /// Total positive responses (done / timer completed) across all time.
        var lifetimePositiveResponses: Int = 0

        /// Observed streak: days the user has opened the app in a row.
        var currentStreakDays: Int = 0
        var lastActiveDate: String = ""

        /// Observations Perch writes automatically when patterns emerge.
        var autoObservations: [Observation] = []

        /// Free-form notes Perch can add or update over sessions.
        var sessionNotes: [String] = []

        struct Observation: Codable, Identifiable {
            var id = UUID()
            var text: String
            var category: String      // "rhythm", "habit", "personality", "milestone"
            var addedAt: Date
            var updatedAt: Date
        }
    }

    // MARK: - State

    private(set) var brain = Brain()
    var isLoaded = false

    @ObservationIgnored private var saveTask: Task<Void, Never>?

    // MARK: - Persistence

    private static let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Perch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("brain.json")
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init() { load() }

    // MARK: - Public API

    /// Called when the user's name changes in preferences.
    func setUserName(_ name: String) {
        guard !name.isEmpty, brain.userName != name else { return }
        brain.userName = name
        scheduleSave()
    }

    /// Log a check in delivery.
    func recordCheckInDelivered() {
        brain.lifetimeCheckIns += 1
        updateStreak()
        scheduleSave()
    }

    /// Log a positive response.
    func recordPositiveResponse(kind: String) {
        brain.lifetimePositiveResponses += 1
        scheduleSave()
    }

    /// Log a water drink.
    func recordWater() {
        brain.lifetimeWaterLogs += 1
        evaluateMilestones()
        scheduleSave()
    }

    /// Log a break.
    func recordBreak() {
        brain.lifetimeBreaks += 1
        evaluateMilestones()
        scheduleSave()
    }

    /// Update focus session data.
    func recordFocusSeconds(_ seconds: Double) {
        if seconds > brain.longestFocusSession {
            brain.longestFocusSession = seconds
            upsertObservation(
                "Their longest focus session on record is \(Int(seconds / 60)) minutes.",
                category: "rhythm"
            )
        }
        let hour = Calendar.current.component(.hour, from: Date())
        let current = brain.peakHours[hour] ?? 0
        brain.peakHours[hour] = (current + seconds) / 2
        evaluatePeakHours()
        scheduleSave()
    }

    /// Called from HabitMemoryStore analysis to update what Perch responds to.
    func updateResponsePatterns(wellTo: [String], ignores: [String]) {
        var changed = false
        if brain.respondedWellTo != wellTo {
            brain.respondedWellTo = wellTo
            changed = true
        }
        if brain.tendsToIgnore != ignores {
            brain.tendsToIgnore = ignores
            changed = true
        }
        if changed {
            if !wellTo.isEmpty {
                upsertObservation(
                    "They respond well to: \(wellTo.joined(separator: ", ")) check ins.",
                    category: "habit"
                )
            }
            if !ignores.isEmpty {
                upsertObservation(
                    "They tend to dismiss: \(ignores.joined(separator: ", ")) check ins. Pick better timing.",
                    category: "habit"
                )
            }
            scheduleSave()
        }
    }

    /// Add a free-form session note (e.g. something the user typed in chat).
    func addNote(_ note: String) {
        guard !note.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if !brain.userNotes.contains(note) {
            brain.userNotes.append(note)
            scheduleSave()
        }
    }

    // MARK: - Context for AI prompts

    /// Returns a concise brain summary to inject into AI system instructions.
    func contextSummary() -> String {
        var lines: [String] = []

        if !brain.userName.isEmpty {
            lines.append("The user's name is \(brain.userName).")
        }

        if brain.lifetimeCheckIns > 0 {
            lines.append("Perch has checked on them \(brain.lifetimeCheckIns) times across all sessions.")
        }

        if brain.currentStreakDays > 1 {
            lines.append("They have been active for \(brain.currentStreakDays) days in a row.")
        }

        if brain.longestFocusSession > 3600 {
            lines.append("Their longest focus session was \(Int(brain.longestFocusSession / 3600))h \(Int((brain.longestFocusSession.truncatingRemainder(dividingBy: 3600)) / 60))m.")
        }

        if !brain.respondedWellTo.isEmpty {
            lines.append("They respond well to \(brain.respondedWellTo.prefix(3).joined(separator: ", ")) reminders.")
        }

        if !brain.tendsToIgnore.isEmpty {
            lines.append("They often dismiss \(brain.tendsToIgnore.prefix(2).joined(separator: " and ")) reminders, so be brief and direct.")
        }

        let relevant = brain.autoObservations
            .sorted { $0.updatedAt > $1.updatedAt }
            .prefix(4)
            .map(\.text)
        lines.append(contentsOf: relevant)

        lines.append(contentsOf: brain.userNotes.prefix(2))

        return lines.joined(separator: " ")
    }

    // MARK: - Private

    private func updateStreak() {
        let today = Self.dayFormatter.string(from: Date())
        guard brain.lastActiveDate != today else { return }
        let yesterday: String = {
            guard let d = Calendar.current.date(byAdding: .day, value: -1, to: Date()) else { return "" }
            return Self.dayFormatter.string(from: d)
        }()
        brain.currentStreakDays = (brain.lastActiveDate == yesterday) ? brain.currentStreakDays + 1 : 1
        brain.lastActiveDate = today
    }

    private func evaluatePeakHours() {
        guard brain.peakHours.count >= 3 else { return }
        let sorted = brain.peakHours.sorted { $0.value > $1.value }
        guard let top = sorted.first else { return }
        let label = hourLabel(top.key)
        upsertObservation(
            "They tend to be most active around \(label).",
            category: "rhythm"
        )
    }

    private func evaluateMilestones() {
        if brain.lifetimeWaterLogs == 100 {
            upsertObservation("Milestone: they have logged 100 water reminders with Perch.", category: "milestone")
        }
        if brain.lifetimeBreaks == 50 {
            upsertObservation("Milestone: 50 real breaks taken. That is how long games are won.", category: "milestone")
        }
        if brain.lifetimePositiveResponses == 200 {
            upsertObservation("Milestone: 200 positive responses. They trust Perch.", category: "milestone")
        }
    }

    private func upsertObservation(_ text: String, category: String) {
        let now = Date()
        if let index = brain.autoObservations.firstIndex(where: { $0.category == category && $0.text.hasPrefix(text.prefix(30)) }) {
            brain.autoObservations[index].text = text
            brain.autoObservations[index].updatedAt = now
        } else {
            brain.autoObservations.append(
                Brain.Observation(text: text, category: category, addedAt: now, updatedAt: now)
            )
            if brain.autoObservations.count > 20 {
                brain.autoObservations.sort { $0.updatedAt > $1.updatedAt }
                brain.autoObservations = Array(brain.autoObservations.prefix(20))
            }
        }
    }

    private func hourLabel(_ hour: Int) -> String {
        let suffix = hour < 12 ? "AM" : "PM"
        let h = hour == 0 ? 12 : (hour > 12 ? hour - 12 : hour)
        return "\(h) \(suffix)"
    }

    // MARK: - Persistence

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    func flush() {
        saveTask?.cancel()
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(brain) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else {
            isLoaded = true
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(Brain.self, from: data) {
            brain = decoded
        }
        isLoaded = true
    }
}
