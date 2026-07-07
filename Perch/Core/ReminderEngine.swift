import Foundation


@MainActor
final class ReminderEngine {

    private let prefs: PreferencesStore
    private let memory: HabitMemoryStore
    private let tracker: FocusSessionTracker
    private let calendar: CalendarAwarenessService
    private let subscriptions: SubscriptionManager


    var onDeliver: ((ReminderKind, CheckInContext) async -> Bool)?

    var isPresenting: (() -> Bool)?

    private var tickTask: Task<Void, Never>?
    private var lastTickAt = Date()
    private var isDelivering = false

    private var lastShownAt: [ReminderKind: Date] = [:]
    private var globalLastShownAt: Date?
    private var snoozedUntil: [ReminderKind: Date] = [:]
    private var pending: Candidate?
    private var pendingSince = Date()
    private var firedOverworkMilestones: Set<Int> = []
    private var promptedEventIDs: Set<String> = []
    private var recoveredEventIDs: Set<String> = []
    private var firedRoutineIDs: Set<UUID> = []
    private var lastWindDownAt: Date?
    private var sleepPromptedDay = ""
    private var routineResetDay = ""
    private var lastSessionHelloAt: Date?

    init(
        prefs: PreferencesStore,
        memory: HabitMemoryStore,
        tracker: FocusSessionTracker,
        calendar: CalendarAwarenessService,
        subscriptions: SubscriptionManager
    ) {
        self.prefs = prefs
        self.memory = memory
        self.tracker = tracker
        self.calendar = calendar
        self.subscriptions = subscriptions
    }

        // MARK: Lifecycle

    func start() {
        guard tickTask == nil else { return }
        lastTickAt = Date()
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                await MainActor.run { self?.tick() }
            }
        }
    }

    func stop() {
        tickTask?.cancel()
        tickTask = nil
    }

        // MARK: Tick

    private func tick() {
        let now = Date()
        let delta = min(max(now.timeIntervalSince(lastTickAt), 0), 30)
        lastTickAt = now
        tracker.update(delta: delta)
        resetDailyStateIfNeeded(now)

        guard prefs.hasOnboarded, !prefs.isPaused(at: now), !prefs.isQuietHours(at: now) else {
            pending = nil
            return
        }
        if isPresenting?() == true || isDelivering { return }

        let gate = subscriptions.gate
        if gate.calendarAwareness, calendar.currentEvent(at: now) != nil {
            return
        }

        if let candidate = bestCandidate(now: now, gate: gate) {
            if pending?.kind == candidate.kind {
                pending = candidate
            } else if pending == nil || candidate.kind.priority > (pending?.kind.priority ?? 0) {
                pending = candidate
                pendingSince = now
            }
        }
        deliverPendingIfTimely(now: now)
    }

    private func resetDailyStateIfNeeded(_ now: Date) {
        let day = ISO8601DateFormatter.perchDay.string(from: now)
        if routineResetDay != day {
            routineResetDay = day
            firedRoutineIDs.removeAll()
        }
        if tracker.focusRunMinutes < 100 {
            firedOverworkMilestones.removeAll()
        }
    }

        // MARK: Candidate selection

    private typealias Candidate = (kind: ReminderKind, context: CheckInContext, commit: () -> Void)

    private func bestCandidate(now: Date, gate: FeatureGate) -> Candidate? {
        var candidates: [Candidate] = []
        if let c = meetingPrepRule(now: now, gate: gate) { candidates.append(c) }
        if let c = mealRule(now: now) { candidates.append(c) }
        if let c = showerRule(now: now) { candidates.append(c) }
        if let c = overworkRule(now: now) { candidates.append(c) }
        if let c = sleepRule(now: now) { candidates.append(c) }
        if let c = windDownRule(now: now) { candidates.append(c) }
        if let c = routineRule(now: now, gate: gate) { candidates.append(c) }
        if let c = walkRule(now: now) { candidates.append(c) }
        if let c = stretchRule(now: now) { candidates.append(c) }
        if let c = waterRule(now: now) { candidates.append(c) }
        if let c = meetingRecoveryRule(now: now, gate: gate) { candidates.append(c) }
        if let c = postureRule(now: now) { candidates.append(c) }
        if let c = eyesRule(now: now) { candidates.append(c) }
        if let c = sessionStartRule(now: now) { candidates.append(c) }
        return candidates.max { $0.kind.priority < $1.kind.priority }
    }


    private func sessionStartRule(now: Date) -> Candidate? {
        let run = tracker.focusRunMinutes
        guard run >= 2, run <= 6 else { return nil }
        if let last = lastSessionHelloAt, now.timeIntervalSince(last) < 3 * 3600 { return nil }
        if let shown = globalLastShownAt, elapsedMinutes(since: shown, now: now) < 30 { return nil }
        return (.sessionStart, CheckInContext(minutes: run), { [weak self] in self?.lastSessionHelloAt = now })
    }

    private func deliverPendingIfTimely(now: Date) {
        guard let pending else { return }
        let highPriority = pending.kind.priority >= 90
        guard cooldownSatisfied(now: now, highPriority: highPriority) else { return }

        let idle = tracker.idleSeconds
        let naturalPause = idle >= 6 && idle <= 240
        let waitedLongEnough = elapsedMinutes(since: pendingSince, now: now) >= 6
        let immediate = highPriority || pending.kind == .sessionStart
        guard naturalPause || waitedLongEnough || immediate else { return }

        let item = pending
        self.pending = nil
        isDelivering = true
        Task { [weak self] in
            guard let self else { return }
            let shown = await self.onDeliver?(item.kind, item.context) ?? false
            self.isDelivering = false
            guard shown else { return }
            item.commit()
            self.lastShownAt[item.kind] = Date()
            self.globalLastShownAt = Date()
            if item.kind.isTrackable {
                self.memory.recordShown(kind: item.kind, mealName: item.context.mealName)
            }
        }
    }

    private func cooldownSatisfied(now: Date, highPriority: Bool) -> Bool {
        guard let last = globalLastShownAt else { return true }
        let gap = highPriority ? 5.0 : 18.0 * prefs.intensity.intervalMultiplier
        return elapsedMinutes(since: last, now: now) >= gap
    }

        // MARK: Rules

    private func waterRule(now: Date) -> Candidate? {
        guard ruleReady(.water, now: now), tracker.focusRunMinutes >= 20 else { return nil }
        guard minutesSinceKindEvent(.water, now: now) >= threshold(50, kind: .water, now: now) else { return nil }
        return (.water, CheckInContext(minutes: tracker.focusRunMinutes), {})
    }

    private func stretchRule(now: Date) -> Candidate? {
        guard ruleReady(.stretch, now: now), tracker.focusRunMinutes >= 25 else { return nil }
        guard minutesSinceKindEvent(.stretch, now: now) >= threshold(55, kind: .stretch, now: now) else { return nil }
        return (.stretch, CheckInContext(minutes: tracker.focusRunMinutes), {})
    }

    private func eyesRule(now: Date) -> Candidate? {
        guard ruleReady(.eyes, now: now), tracker.focusRunMinutes >= 20 else { return nil }
        guard minutesSinceKindEvent(.eyes, now: now) >= threshold(40, kind: .eyes, now: now) else { return nil }
        return (.eyes, CheckInContext(minutes: tracker.focusRunMinutes), {})
    }

    private func postureRule(now: Date) -> Candidate? {
        guard ruleReady(.posture, now: now), tracker.focusRunMinutes >= 30 else { return nil }
        guard minutesSinceKindEvent(.posture, now: now) >= threshold(95, kind: .posture, now: now) else { return nil }
        return (.posture, CheckInContext(minutes: tracker.focusRunMinutes), {})
    }

    private func walkRule(now: Date) -> Candidate? {
        guard ruleReady(.walk, now: now), tracker.focusRunMinutes >= 110 else { return nil }
        guard minutesSinceKindEvent(.walk, now: now) >= threshold(110, kind: .walk, now: now) else { return nil }
        return (.walk, CheckInContext(minutes: tracker.focusRunMinutes), {})
    }

    private func overworkRule(now: Date) -> Candidate? {
        guard ruleReady(.overwork, now: now) else { return nil }
        let run = tracker.focusRunMinutes
        for milestone in [110, 170, 230, 290] where run >= milestone && !firedOverworkMilestones.contains(milestone) {
            return (.overwork, CheckInContext(minutes: run), { [weak self] in self?.firedOverworkMilestones.insert(milestone) })
        }
        return nil
    }

    private func mealRule(now: Date) -> Candidate? {
        guard ruleReady(.meal, now: now) else { return nil }
        let nowMinute = minutesOfDay(now)
        let today = memory.today(now)
        let meals: [(name: String, minute: Int, logged: Bool, prompted: Bool)] = [
            ("breakfast", prefs.breakfastMinutes, today.breakfastLogged, today.breakfastPrompted),
            ("lunch", prefs.lunchMinutes, today.lunchLogged, today.lunchPrompted),
            ("dinner", prefs.dinnerMinutes, today.dinnerLogged, today.dinnerPrompted),
        ]
        for meal in meals {
            let window = (meal.minute - 30)...(meal.minute + 120)
            guard window.contains(nowMinute), !meal.logged, !meal.prompted else { continue }
            let skipped = memory.skippedMealYesterday(meal: meal.name, from: now)
            return (.meal, CheckInContext(mealName: meal.name, yesterdaySkipped: skipped), {})
        }
        return nil
    }

    private func showerRule(now: Date) -> Candidate? {
        guard ruleReady(.shower, now: now) else { return nil }
        let nowMinute = minutesOfDay(now)
        let today = memory.today(now)
        guard !today.showerLogged, !today.showerPrompted else { return nil }
        let window = (prefs.showerMinutes - 15)...(prefs.showerMinutes + 90)
        guard window.contains(nowMinute) else { return nil }
        return (.shower, CheckInContext(), {})
    }

    private func windDownRule(now: Date) -> Candidate? {
        guard ruleReady(.windDown, now: now) else { return nil }
        guard minutesOfDay(now) >= prefs.workEndMinutes + 30, tracker.idleSeconds < 120 else { return nil }
        if let last = lastWindDownAt, elapsedMinutes(since: last, now: now) < 45 { return nil }
        return (.windDown, CheckInContext(minutes: tracker.focusRunMinutes), { [weak self] in self?.lastWindDownAt = now })
    }

    private func sleepRule(now: Date) -> Candidate? {
        guard ruleReady(.sleep, now: now) else { return nil }
        let day = ISO8601DateFormatter.perchDay.string(from: now)
        guard sleepPromptedDay != day else { return nil }
        let nowMinute = minutesOfDay(now)
        let window = (prefs.quietStartMinutes - 20)..<prefs.quietStartMinutes
        guard window.contains(nowMinute), tracker.idleSeconds < 120 else { return nil }
        return (.sleep, CheckInContext(minutes: tracker.focusRunMinutes), { [weak self] in self?.sleepPromptedDay = day })
    }

    private func meetingPrepRule(now: Date, gate: FeatureGate) -> Candidate? {
        guard gate.calendarAwareness, ruleReady(.meetingPrep, now: now) else { return nil }
        guard let event = calendar.nextEvent(startingWithinMinutes: 15, at: now) else { return nil }
        guard !promptedEventIDs.contains(event.id) else { return nil }
        let minutes = max(Int(event.start.timeIntervalSince(now) / 60), 1)
        return (.meetingPrep, CheckInContext(eventTitle: event.title, minutesUntil: minutes), { [weak self] in self?.promptedEventIDs.insert(event.id) })
    }

    private func meetingRecoveryRule(now: Date, gate: FeatureGate) -> Candidate? {
        guard gate.calendarAwareness, ruleReady(.meetingRecovery, now: now) else { return nil }
        guard let event = calendar.recentlyEndedMeeting(withinMinutes: 6, minimumDurationMinutes: 45, at: now) else { return nil }
        guard !recoveredEventIDs.contains(event.id) else { return nil }
        return (.meetingRecovery, CheckInContext(eventTitle: event.title), { [weak self] in self?.recoveredEventIDs.insert(event.id) })
    }

    private func routineRule(now: Date, gate: FeatureGate) -> Candidate? {
        let nowMinute = minutesOfDay(now)
        let active = prefs.routines.prefix(gate.maxRoutines)
        for routine in active where routine.enabled && !firedRoutineIDs.contains(routine.id) {
            if (routine.minuteOfDay...(routine.minuteOfDay + 15)).contains(nowMinute) {
                return (.routine, CheckInContext(routineLabel: routine.label), { [weak self] in self?.firedRoutineIDs.insert(routine.id) })
            }
        }
        return nil
    }

        // MARK: Responses

    func applyResponse(kind: ReminderKind, response: CheckInResponse, context: CheckInContext) {
        let now = Date()
        if kind.isTrackable {
            memory.recordResponse(kind: kind, response: response)
        }
        switch response {
        case .snoozed(let minutes):
            snoozedUntil[kind] = now.addingTimeInterval(Double(minutes) * 60 / prefs.demoTimeScale)
        case .done, .timerCompleted:
            switch kind {
            case .water: memory.logWater(at: now)
            case .meal: memory.logMeal(mealName: context.mealName, at: now)
            case .shower: memory.logShower(at: now)
            case .stretch, .walk, .eyes, .overwork, .meetingRecovery: tracker.creditBreak()
            default: break
            }
        case .ignored, .timedOut:
            break
        }
        pending = nil
    }


    func forceCheckIn() async {
        let now = Date()
        let run = tracker.focusRunMinutes
        let today = memory.today(now)
        let choice: (ReminderKind, CheckInContext)
        if run >= 100 {
            choice = (.overwork, CheckInContext(minutes: run))
        } else if let meal = forceMealChoice(now: now, today: today) {
            choice = meal
        } else if run >= 30 {
            choice = (.stretch, CheckInContext(minutes: run))
        } else if minutesSinceKindEvent(.water, now: now) >= 25 && run >= 5 {
            choice = (.water, CheckInContext(minutes: run))
        } else {
            choice = (.status, CheckInContext(minutes: run))
        }
        let shown = await onDeliver?(choice.0, choice.1) ?? false
        if shown {
            lastShownAt[choice.0] = Date()
            globalLastShownAt = Date()
            if choice.0.isTrackable {
                memory.recordShown(kind: choice.0, mealName: choice.1.mealName)
            }
        }
    }

    private func forceMealChoice(now: Date, today: HabitMemoryStore.DayLog) -> (ReminderKind, CheckInContext)? {
        let nowMinute = minutesOfDay(now)
        let meals: [(name: String, minute: Int, logged: Bool)] = [
            ("breakfast", prefs.breakfastMinutes, today.breakfastLogged),
            ("lunch", prefs.lunchMinutes, today.lunchLogged),
            ("dinner", prefs.dinnerMinutes, today.dinnerLogged),
        ]
        for meal in meals {
            if ((meal.minute - 30)...(meal.minute + 120)).contains(nowMinute), !meal.logged {
                return (.meal, CheckInContext(mealName: meal.name, yesterdaySkipped: memory.skippedMealYesterday(meal: meal.name)))
            }
        }
        return nil
    }


    func nextHint(now: Date = Date()) -> String? {
        guard tracker.isInSession else { return nil }
        var remaining: [Double] = []
        if prefs.enabledKinds.contains(.water) {
            remaining.append(threshold(50, kind: .water, now: now) - minutesSinceKindEvent(.water, now: now))
        }
        if prefs.enabledKinds.contains(.stretch) {
            remaining.append(threshold(55, kind: .stretch, now: now) - minutesSinceKindEvent(.stretch, now: now))
        }
        guard let soonest = remaining.min() else { return nil }
        if soonest <= 0 { return "A check in is coming at your next pause" }
        return "Next gentle check in about \(Int(soonest.rounded(.up)))m away"
    }

        // MARK: Helpers

    private func ruleReady(_ kind: ReminderKind, now: Date) -> Bool {
        guard prefs.enabledKinds.contains(kind) else { return false }
        if let until = snoozedUntil[kind], now < until { return false }
        return true
    }


    private func threshold(_ base: Double, kind: ReminderKind, now: Date) -> Double {
        let memoryMultiplier = subscriptions.gate.adaptiveMemory
            ? memory.intervalMultiplier(kind: kind, at: now)
            : 1.0
        return base * prefs.intensity.intervalMultiplier * memoryMultiplier
    }


    private func minutesSinceKindEvent(_ kind: ReminderKind, now: Date) -> Double {
        let runStart = now.addingTimeInterval(-tracker.focusRunSeconds / prefs.demoTimeScale)
        var anchor = runStart
        if let shown = lastShownAt[kind], shown > anchor { anchor = shown }
        if let accepted = memory.lastAccepted(kind), accepted > anchor { anchor = accepted }
        if let brk = tracker.lastBreakAt, kind == .stretch || kind == .walk, brk > anchor { anchor = brk }
        return elapsedMinutes(since: anchor, now: now)
    }

    private func elapsedMinutes(since date: Date, now: Date) -> Double {
        now.timeIntervalSince(date) / 60 * prefs.demoTimeScale
    }
}

extension ISO8601DateFormatter {
    static let perchDay: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate]
        return formatter
    }()
}
