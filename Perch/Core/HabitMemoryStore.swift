import Foundation
import Observation


@MainActor
@Observable
final class HabitMemoryStore {

    struct ResponseStat: Codable {
        var shown = 0
        var accepted = 0
        var snoozed = 0
        var ignored = 0

        var acceptanceRate: Double {
            shown > 0 ? Double(accepted) / Double(shown) : 0
        }

        var ignoreRate: Double {
            shown > 0 ? Double(ignored) / Double(shown) : 0
        }
    }

    struct DayLog: Codable, Identifiable {
        var date: String
        var activeSeconds: Double = 0
        var breaksTaken = 0
        var waterCount = 0
        var breakfastPrompted = false
        var breakfastLogged = false
        var lunchPrompted = false
        var lunchLogged = false
        var dinnerPrompted = false
        var dinnerLogged = false
        var showerPrompted = false
        var showerLogged = false
        var overworkSeconds: Double = 0
        var checkInsShown = 0
        var checkInsAccepted = 0

        var mealsLogged: Int { [breakfastLogged, lunchLogged, dinnerLogged].filter { $0 }.count }

        var id: String { date }
    }

    struct Snapshot: Codable {
        var stats: [String: ResponseStat] = [:]
        var days: [DayLog] = []
        var lastAccepted: [String: Date] = [:]
    }

    private(set) var snapshot = Snapshot()
    @ObservationIgnored private var saveTask: Task<Void, Never>?


    @ObservationIgnored var onWaterLogged: (() -> Void)?
    @ObservationIgnored var onBreakTaken: (() -> Void)?
    @ObservationIgnored var onResponseRecorded: (() -> Void)?
    @ObservationIgnored var onMealLogged: (() -> Void)?
    @ObservationIgnored var onShowerLogged: (() -> Void)?

    private static let fileURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("Perch", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("memory.json")
    }()

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    init() {
        load()
    }

        // MARK: Recording

    func recordShown(kind: ReminderKind, mealName: String? = nil, at date: Date = Date()) {
        mutate { snap in
            snap.stats[Self.statKey(kind, date), default: ResponseStat()].shown += 1
            snap.days[Self.dayIndex(&snap, date)].checkInsShown += 1
            if kind == .meal {
                let meal = mealName ?? Self.defaultMealName(for: date)
                Self.setMealPrompted(&snap.days[Self.dayIndex(&snap, date)], meal: meal)
            }
            if kind == .shower {
                snap.days[Self.dayIndex(&snap, date)].showerPrompted = true
            }
        }
    }

    func recordResponse(kind: ReminderKind, response: CheckInResponse, at date: Date = Date()) {
        mutate { snap in
            let key = Self.statKey(kind, date)
            switch response {
            case .done, .timerCompleted:
                snap.stats[key, default: ResponseStat()].accepted += 1
                snap.lastAccepted[kind.rawValue] = date
                snap.days[Self.dayIndex(&snap, date)].checkInsAccepted += 1
            case .snoozed:
                snap.stats[key, default: ResponseStat()].snoozed += 1
            case .ignored, .timedOut:
                snap.stats[key, default: ResponseStat()].ignored += 1
            }
        }
        onResponseRecorded?()
    }

    func addActive(seconds: Double, at date: Date = Date()) {
        mutate { snap in
            snap.days[Self.dayIndex(&snap, date)].activeSeconds += seconds
        }
    }

    func addOverwork(seconds: Double, at date: Date = Date()) {
        mutate { snap in
            snap.days[Self.dayIndex(&snap, date)].overworkSeconds += seconds
        }
    }

    func creditBreak(at date: Date = Date()) {
        mutate { snap in
            snap.days[Self.dayIndex(&snap, date)].breaksTaken += 1
        }
        onBreakTaken?()
    }

    func logWater(at date: Date = Date()) {
        mutate { snap in
            snap.days[Self.dayIndex(&snap, date)].waterCount += 1
        }
        recordAccepted(kind: .water, at: date)
        onWaterLogged?()
    }

    func logMeal(mealName: String? = nil, at date: Date = Date()) {
        let meal = mealName ?? Self.defaultMealName(for: date)
        mutate { snap in
            Self.setMealLogged(&snap.days[Self.dayIndex(&snap, date)], meal: meal)
        }
        recordAccepted(kind: .meal, at: date)
        onMealLogged?()
    }

    func logShower(at date: Date = Date()) {
        mutate { snap in
            snap.days[Self.dayIndex(&snap, date)].showerLogged = true
        }
        onShowerLogged?()
    }

    private func recordAccepted(kind: ReminderKind, at date: Date) {
        mutate { snap in
            snap.lastAccepted[kind.rawValue] = date
        }
    }

        // MARK: Queries

    func today(_ date: Date = Date()) -> DayLog {
        let key = Self.dayFormatter.string(from: date)
        return snapshot.days.first { $0.date == key } ?? DayLog(date: key)
    }

    func lastAccepted(_ kind: ReminderKind) -> Date? {
        snapshot.lastAccepted[kind.rawValue]
    }

    func skippedMealYesterday(meal: String, from date: Date = Date()) -> Bool {
        guard let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: date) else { return false }
        let key = Self.dayFormatter.string(from: yesterday)
        guard let day = snapshot.days.first(where: { $0.date == key }) else { return false }
        return Self.mealPrompted(day, meal: meal) && !Self.mealLogged(day, meal: meal)
    }


    func intervalMultiplier(kind: ReminderKind, at date: Date = Date()) -> Double {
        guard let stat = snapshot.stats[Self.statKey(kind, date)], stat.shown >= 4 else { return 1.0 }
        if stat.ignoreRate > 0.8 { return 1.9 }
        if stat.ignoreRate > 0.6 { return 1.45 }
        if stat.acceptanceRate > 0.7 { return 0.85 }
        return 1.0
    }


    func learnedPatterns() -> (wellTo: [String], ignores: [String]) {
        var totals: [String: (shown: Int, accepted: Int, ignored: Int)] = [:]
        for (key, stat) in snapshot.stats {
            let kindRaw = String(key.split(separator: "|").first ?? "")
            var current = totals[kindRaw] ?? (0, 0, 0)
            current.shown += stat.shown
            current.accepted += stat.accepted
            current.ignored += stat.ignored
            totals[kindRaw] = current
        }
        var wellTo: [String] = []
        var ignores: [String] = []
        for (kindRaw, t) in totals where t.shown >= 6 {
            let name = ReminderKind(rawValue: kindRaw)?.displayName.lowercased() ?? kindRaw
            if Double(t.accepted) / Double(t.shown) >= 0.6 { wellTo.append(name) }
            else if Double(t.ignored) / Double(t.shown) >= 0.6 { ignores.append(name) }
        }
        return (wellTo.sorted(), ignores.sorted())
    }

    func weekSummary(from date: Date = Date()) -> WeekSummary {
        let calendar = Calendar.current
        let days: [DayLog] = (0..<7).reversed().compactMap { offset in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: date) else { return nil }
            let key = Self.dayFormatter.string(from: day)
            return snapshot.days.first { $0.date == key } ?? DayLog(date: key)
        }
        return WeekSummary(days: days, insight: insight(days: days))
    }

    private func insight(days: [DayLog]) -> String {
        let overworkDays = days.filter { $0.overworkSeconds > 1800 }.count
        if overworkDays >= 3 {
            return "You pushed past your work hours on \(overworkDays) days this week. Guard your evenings, they are where you recover."
        }
        let worst = snapshot.stats
            .filter { $0.value.shown >= 4 }
            .min { $0.value.acceptanceRate < $1.value.acceptanceRate }
        if let worst, worst.value.acceptanceRate < 0.4 {
            let parts = worst.key.split(separator: "|").map(String.init)
            let kindName = ReminderKind(rawValue: parts.first ?? "")?.displayName.lowercased() ?? "break"
            let daypart = Daypart(rawValue: parts.last ?? "")?.displayName ?? "day"
            return "You tend to skip \(kindName) check ins in the \(daypart). I'll pick better moments for those."
        }
        let breaks = days.reduce(0) { $0 + $1.breaksTaken }
        if breaks >= 10 {
            return "You took \(breaks) real breaks this week. That is how long games are won."
        }
        return "Still learning your rhythm. The more you respond, the better my timing gets."
    }

        // MARK: Maintenance

    func wipe() {
        snapshot = Snapshot()
        try? FileManager.default.removeItem(at: Self.fileURL)
    }

    func flush() {
        saveTask?.cancel()
        persist()
    }

        // MARK: Private

    private static func statKey(_ kind: ReminderKind, _ date: Date) -> String {
        "\(kind.rawValue)|\(Daypart.from(date).rawValue)"
    }

    private static func dayIndex(_ snap: inout Snapshot, _ date: Date) -> Int {
        let key = dayFormatter.string(from: date)
        if let index = snap.days.firstIndex(where: { $0.date == key }) { return index }
        snap.days.append(DayLog(date: key))
        if snap.days.count > 45 { snap.days.removeFirst(snap.days.count - 45) }
        return snap.days.count - 1
    }

    private static func defaultMealName(for date: Date) -> String {
        let hour = Calendar.current.component(.hour, from: date)
        if hour < 11 { return "breakfast" }
        if hour < 16 { return "lunch" }
        return "dinner"
    }

    private static func setMealPrompted(_ day: inout DayLog, meal: String) {
        switch meal {
        case "breakfast": day.breakfastPrompted = true
        case "lunch": day.lunchPrompted = true
        default: day.dinnerPrompted = true
        }
    }

    private static func setMealLogged(_ day: inout DayLog, meal: String) {
        switch meal {
        case "breakfast": day.breakfastLogged = true
        case "lunch": day.lunchLogged = true
        default: day.dinnerLogged = true
        }
    }

    private static func mealPrompted(_ day: DayLog, meal: String) -> Bool {
        switch meal {
        case "breakfast": day.breakfastPrompted
        case "lunch": day.lunchPrompted
        default: day.dinnerPrompted
        }
    }

    private static func mealLogged(_ day: DayLog, meal: String) -> Bool {
        switch meal {
        case "breakfast": day.breakfastLogged
        case "lunch": day.lunchLogged
        default: day.dinnerLogged
        }
    }

    private func mutate(_ change: (inout Snapshot) -> Void) {
        var copy = snapshot
        change(&copy)
        snapshot = copy
        scheduleSave()
    }

    private func scheduleSave() {
        saveTask?.cancel()
        saveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            self?.persist()
        }
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return }
        try? data.write(to: Self.fileURL, options: .atomic)
    }

    private func load() {
        guard let data = try? Data(contentsOf: Self.fileURL) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(Snapshot.self, from: data) {
            snapshot = decoded
        }
    }
}

struct WeekSummary {
    let days: [HabitMemoryStore.DayLog]
    let insight: String

    var totalActiveSeconds: Double { days.reduce(0) { $0 + $1.activeSeconds } }
    var totalBreaks: Int { days.reduce(0) { $0 + $1.breaksTaken } }
    var totalWater: Int { days.reduce(0) { $0 + $1.waterCount } }
    var overworkDays: Int { days.filter { $0.overworkSeconds > 1800 }.count }

    var acceptanceRate: Double {
        let shown = days.reduce(0) { $0 + $1.checkInsShown }
        let accepted = days.reduce(0) { $0 + $1.checkInsAccepted }
        return shown > 0 ? Double(accepted) / Double(shown) : 0
    }
}
