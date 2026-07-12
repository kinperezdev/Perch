import Foundation
import Observation
@MainActor
@Observable
final class PerchBrain {

    struct Brain: Codable {
        var userName: String = ""
        var userNotes: [String] = []
        var peakHours: [Int: Double] = [:]
        var respondedWellTo: [String] = []
        var tendsToIgnore: [String] = []
        var longestFocusSession: Double = 0
        var lifetimeWaterLogs: Int = 0
        var lifetimeBreaks: Int = 0
        var lifetimeMealLogs: Int = 0
        var lifetimeShowerLogs: Int = 0
        var mealLogHours: [Int: Int] = [:]
        var showerLogHours: [Int: Int] = [:]
        var lifetimeCheckIns: Int = 0
        var lifetimePositiveResponses: Int = 0
        var currentStreakDays: Int = 0
        var lastActiveDate: String = ""
        var autoObservations: [Observation] = []
        var sessionNotes: [String] = []

        struct Observation: Codable, Identifiable {
            var id = UUID()
            var text: String
            var category: String
            var addedAt: Date
            var updatedAt: Date
        }
    }

    private(set) var brain = Brain()
    var isLoaded = false

    @ObservationIgnored private var saveTask: Task<Void, Never>?

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
    func setUserName(_ name: String) {
        guard !name.isEmpty, brain.userName != name else { return }
        brain.userName = name
        scheduleSave()
    }
    func recordCheckInDelivered() {
        brain.lifetimeCheckIns += 1
        updateStreak()
        scheduleSave()
    }
    func recordPositiveResponse() {
        brain.lifetimePositiveResponses += 1
        evaluateMilestones()
        scheduleSave()
    }
    func recordWater() {
        brain.lifetimeWaterLogs += 1
        evaluateMilestones()
        scheduleSave()
    }
    func recordBreak() {
        brain.lifetimeBreaks += 1
        evaluateMilestones()
        scheduleSave()
    }

    func recordMeal(at date: Date = Date()) {
        brain.lifetimeMealLogs += 1
        let hour = Calendar.current.component(.hour, from: date)
        brain.mealLogHours[hour, default: 0] += 1
        evaluateMealPattern()
        scheduleSave()
    }

    func recordShower(at date: Date = Date()) {
        brain.lifetimeShowerLogs += 1
        let hour = Calendar.current.component(.hour, from: date)
        brain.showerLogHours[hour, default: 0] += 1
        evaluateShowerPattern()
        scheduleSave()
    }
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

    func absorbAIInsight(_ text: String, category: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 200 else { return }
        if category == "name" {
            setUserName(trimmed)
            return
        }
        upsertObservation(trimmed, category: category)
        scheduleSave()
    }

    func addNote(_ note: String) {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard !brain.userNotes.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }
        brain.userNotes.insert(trimmed, at: 0)
        if brain.userNotes.count > 40 {
            brain.userNotes.removeLast(brain.userNotes.count - 40)
        }
        scheduleSave()
    }

    func absorbChatMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 8, trimmed.count <= 260 else { return }
        guard shouldRemember(trimmed) else { return }
        addNote("They said: \(trimmed)")
    }

    func wipe(keepingUserName userName: String = "") {
        saveTask?.cancel()
        brain = Brain()
        let trimmedName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedName.isEmpty {
            brain.userName = trimmedName
        }
        try? FileManager.default.removeItem(at: Self.fileURL)
        if !trimmedName.isEmpty {
            persist()
        }
    }

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

        lines.append(contentsOf: brain.userNotes.prefix(4))

        return lines.joined(separator: " ")
    }

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

    private func shouldRemember(_ text: String) -> Bool {
        let lowered = text.lowercased()
        let crisisSignals = [
            "kill myself", "suicide", "suicidal", "end my life", "end it all",
            "hurt myself", "harm myself", "self harm", "self-harm",
            "don't want to live", "dont want to live", "no reason to live",
        ]
        if crisisSignals.contains(where: lowered.contains) { return false }
        let memorySignals = [
            "remember", "call me", "my name", "i am ", "i'm ", "im ",
            "i like", "i love", "i hate", "i prefer", "i usually", "i always",
            "i struggle", "i need", "i want", "my goal", "my project",
            "working on", "building", "i feel", "i get", "i keep",
        ]
        return memorySignals.contains(where: lowered.contains)
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

    private func evaluateMealPattern() {
        guard brain.lifetimeMealLogs >= 3, let top = brain.mealLogHours.max(by: { $0.value < $1.value }) else { return }
        upsertObservation("Meal routine: they usually eat around \(hourLabel(top.key)).", category: "routine-meal")
    }

    private func evaluateShowerPattern() {
        guard brain.lifetimeShowerLogs >= 3, let top = brain.showerLogHours.max(by: { $0.value < $1.value }) else { return }
        upsertObservation("Shower routine: they usually shower around \(hourLabel(top.key)).", category: "routine-shower")
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
