import Foundation
import Observation
import SwiftUI
@MainActor
@Observable
final class CompanionCoordinator {

    enum Phase: Equatable {
        case hidden
        case message
        case timer
        case confirmation
    }

    private(set) var phase: Phase = .hidden
    private(set) var current: CheckIn?
    private(set) var confirmationText = ""
    private(set) var timerRemaining = 0
    private(set) var timerTotal = 60
    private(set) var timeoutProgress: Double = 0
    private(set) var metrics = NotchMetrics()
    var isHovering = false

    var applyResponse: ((ReminderKind, CheckInResponse, CheckInContext) -> Void)?

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored private let memory: HabitMemoryStore
    @ObservationIgnored private let personality: PersonalityEngine
    @ObservationIgnored private let voice: VoiceService
    @ObservationIgnored private let music: BreakMusicService
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let tracker: FocusSessionTracker
    @ObservationIgnored private let subscriptions: SubscriptionManager
    @ObservationIgnored private let brain: PerchBrain
    @ObservationIgnored private let panel = NotchPanelController()

    @ObservationIgnored private var timeoutTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var confirmationTask: Task<Void, Never>?
    @ObservationIgnored private var lastCheckIn: CheckIn?
    @ObservationIgnored private var lastCheckInAnswered = true

    init(
        prefs: PreferencesStore,
        memory: HabitMemoryStore,
        personality: PersonalityEngine,
        voice: VoiceService,
        music: BreakMusicService,
        notifications: NotificationService,
        tracker: FocusSessionTracker,
        subscriptions: SubscriptionManager,
        brain: PerchBrain
    ) {
        self.prefs = prefs
        self.memory = memory
        self.personality = personality
        self.voice = voice
        self.music = music
        self.notifications = notifications
        self.tracker = tracker
        self.subscriptions = subscriptions
        self.brain = brain
    }
    func prepare() {
        panel.attach(NotchCompanionView(coordinator: self).environment(prefs))
    }

    var accentColors: [Color] { personality.activePersonality.accentColors }
    var activePersonality: Personality { personality.activePersonality }
    var companionName: String { personality.companionName }
    var gate: FeatureGate { subscriptions.gate }
    var isPresenting: Bool { phase != .hidden }
    var todayLog: HabitMemoryStore.DayLog { memory.today() }

    func present(kind: ReminderKind, context: CheckInContext) async -> Bool {
        guard phase == .hidden else { return false }
        let brainCtx = brain.contextSummary()
        let message = await personality.composeLine(for: kind, context: context, aiAllowed: true, brainContext: brainCtx)
        guard phase == .hidden else { return false }

        let checkIn = CheckIn(kind: kind, message: message, context: context)
        current = checkIn
        lastCheckIn = checkIn
        lastCheckInAnswered = false
        reveal(.message)
        voice.speakIfAllowed(message)
        notifications.mirror(checkIn)
        startTimeout(seconds: 30)
        if kind.isTrackable {
            brain.recordCheckInDelivered()
        }
        return true
    }

    func showWelcome() {
        Task { _ = await present(kind: .welcome, context: .empty) }
    }

    func presentStatus() {
        Task {
            _ = await present(
                kind: .status,
                context: CheckInContext(minutes: tracker.focusRunMinutes)
            )
        }
    }

    func respond(_ response: CheckInResponse) {
        guard phase == .message else { return }
        cancelTimeout()
        respondBackground(response)
        showConfirmation(personality.confirmation(for: response, kind: current?.kind))
    }

    private func respondBackground(_ response: CheckInResponse) {
        guard let current else { return }
        lastCheckInAnswered = true
        if current.kind.isTrackable {
            applyResponse?(current.kind, response, current.context)
        }
        if response.isPositive {
            brain.recordPositiveResponse()
        }
    }

    func startTimer() {
        guard let current, phase == .message else { return }
        cancelTimeout()
        let seconds = current.computedTimerSeconds(prefs: prefs)
        timerTotal = seconds
        timerRemaining = seconds
        tracker.beginRest()
        reveal(.timer)
        music.start()
        timerTask?.cancel()
        timerTask = Task { [weak self] in
            while let self, self.timerRemaining > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                self.timerRemaining -= 1
            }
            await MainActor.run { self?.finishTimer(completed: true) }
        }
    }

    func finishTimer(completed: Bool) {
        guard phase == .timer, let current else { return }
        timerTask?.cancel()
        music.stop()
        tracker.endRest()
        lastCheckInAnswered = true
        let response: CheckInResponse = completed ? .timerCompleted : .done
        if current.kind.isTrackable {
            applyResponse?(current.kind, response, current.context)
        }
        showConfirmation(personality.confirmation(for: response))
    }

    /// Logs a habit from the bubble's + menu without dismissing the check in.
    func quickLog(_ topic: ChatTopic) {
        switch topic {
        case .water: memory.logWater()
        case .meal: memory.logMeal()
        case .breakTime: tracker.creditBreak()
        case .shower: memory.logShower()
        }
    }

    func respondMood(_ mood: ChatScriptLibrary.Mood) {
        guard phase == .message else { return }
        cancelTimeout()
        lastCheckInAnswered = true
        if mood == .great {
            brain.recordPositiveResponse()
        }
        let call = activePersonality.callName(userName: prefs.userName)
        showConfirmation(ChatScriptLibrary.moodConfirmation(mood, activePersonality, callName: call))
    }

    func respondThanks() {
        guard phase == .message, let current else { return }
        cancelTimeout()
        lastCheckInAnswered = true
        if current.kind.isTrackable {
            applyResponse?(current.kind, .ignored, current.context)
        }
        showConfirmation(personality.thanksLine())
    }

    func goodnight() {
        guard let current, current.kind == .windDown || current.kind == .sleep else { return }
        respond(.done)
        guard prefs.allowSleepAtGoodnight else { return }
        Task {
            await voice.waitUntilFinished()
            SystemSleepService.sleepMac()
        }
    }

    func quickAnswerPressed() {
        switch phase {
        case .hidden:
            if let last = lastCheckIn, !lastCheckInAnswered,
               Date().timeIntervalSince(last.createdAt) < 30 * 60 {
                represent(last)
            } else {
                presentStatus()
            }
        case .message:
            panel.makeKey()
        case .confirmation:
            hide()
        case .timer:
            break
        }
    }

    private func represent(_ checkIn: CheckIn) {
        current = checkIn
        reveal(.message)
        panel.makeKey()
        startTimeout(seconds: 30)
    }

    func hide() {
        cancelTimeout()
        timerTask?.cancel()
        music.stop()
        tracker.endRest()
        confirmationTask?.cancel()
        phase = .hidden
        panel.hide(afterDelay: 0.45)
    }

    func handleScreenChange() {
        guard phase != .hidden else { return }
        reveal(phase)
    }

    private func reveal(_ newPhase: Phase) {
        let refreshed = panel.refreshMetrics()
        let size = Self.size(for: newPhase, metrics: refreshed)
        metrics = panel.show(width: size.width, contentHeight: size.height)
        phase = newPhase
    }

    private func showConfirmation(_ text: String) {
        confirmationText = text
        reveal(.confirmation)
        voice.speakIfAllowed(text)
        confirmationTask?.cancel()
        confirmationTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled, self?.phase == .confirmation else { return }
            self?.hide()
        }
    }

    private static func size(for phase: Phase, metrics: NotchMetrics) -> CGSize {
        let anchor: CGFloat = metrics.hasNotch ? metrics.notchWidth : 185
        let notchMessageExtra: CGFloat = metrics.hasNotch ? 320 : 260
        switch phase {
        case .hidden:
            return CGSize(width: max(anchor + 40, 250), height: 132)
        case .timer:
            if metrics.hasNotch {
                return CGSize(width: metrics.notchWidth + 240, height: metrics.topInset + 90)
            } else {
                return CGSize(width: 250, height: 140)
            }
        case .confirmation:
            return CGSize(width: max(anchor + 120, 320), height: 76)
        case .message:
            return CGSize(width: max(anchor + notchMessageExtra, 520), height: 140)
        }
    }

    private func startTimeout(seconds: Double) {
        cancelTimeout()
        timeoutProgress = 0
        guard prefs.autoHideMessages else { return }
        timeoutTask = Task { [weak self] in
            var elapsed: Double = 0
            while elapsed < seconds, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self, !Task.isCancelled else { return }
                if !self.isHovering {
                    elapsed += 0.1
                    self.timeoutProgress = min(elapsed / seconds, 1)
                }
            }
            guard let self, !Task.isCancelled else { return }
            if let current = self.current, current.kind.isTrackable {
                self.lastCheckInAnswered = true
                self.applyResponse?(current.kind, .timedOut, current.context)
            }
            self.hide()
        }
    }

    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
        timeoutProgress = 0
    }
}
