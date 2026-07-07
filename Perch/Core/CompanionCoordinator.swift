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
        case chat
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
    @ObservationIgnored private let notifications: NotificationService
    @ObservationIgnored private let tracker: FocusSessionTracker
    @ObservationIgnored private let subscriptions: SubscriptionManager
    @ObservationIgnored private let brain: PerchBrain
    @ObservationIgnored let chat: CompanionChatService
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
        notifications: NotificationService,
        tracker: FocusSessionTracker,
        subscriptions: SubscriptionManager,
        brain: PerchBrain,
        chat: CompanionChatService
    ) {
        self.prefs = prefs
        self.memory = memory
        self.personality = personality
        self.voice = voice
        self.notifications = notifications
        self.tracker = tracker
        self.subscriptions = subscriptions
        self.brain = brain
        self.chat = chat
    }
    func prepare() {
        panel.attach(NotchCompanionView(coordinator: self))
    }

    var accentColors: [Color] { personality.activePersonality.accentColors }
    var activePersonality: Personality { personality.activePersonality }
    var companionName: String { personality.companionName }
    var gate: FeatureGate { subscriptions.gate }
    var isPresenting: Bool { phase != .hidden }
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
        showConfirmation(personality.confirmation(for: response))
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

    func startTimer(seconds: Int = 60) {
        guard current != nil, phase == .message else { return }
        cancelTimeout()
        timerTotal = seconds
        timerRemaining = seconds
        reveal(.timer)
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
        lastCheckInAnswered = true
        let response: CheckInResponse = completed ? .timerCompleted : .done
        if current.kind.isTrackable {
            applyResponse?(current.kind, response, current.context)
        }
        showConfirmation(personality.confirmation(for: response))
    }

    func logWaterQuick() {
        memory.logWater()
        cancelTimeout()
        showConfirmation(personality.confirmation(for: .done))
    }

    func takeBreakQuick() {
        tracker.creditBreak()
        cancelTimeout()
        showConfirmation(personality.confirmation(for: .done))
    }

    func logMealQuick() {
        memory.logMeal()
        cancelTimeout()
        showConfirmation(personality.confirmation(for: .done))
    }

    func logShowerQuick() {
        memory.logShower()
        cancelTimeout()
        showConfirmation(personality.confirmation(for: .done))
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
        case .chat, .confirmation:
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

    func openChat() {
        cancelTimeout()
        chat.openIfNeeded()
        reveal(.chat)
        panel.makeKey()
    }

    func hide() {
        cancelTimeout()
        timerTask?.cancel()
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
            return CGSize(width: max(anchor - 20, 235), height: 94)
        case .confirmation:
            return CGSize(width: max(anchor, 245), height: 58)
        case .message:
            return CGSize(width: max(anchor + notchMessageExtra, 520), height: 140)
        case .chat:
            return CGSize(width: max(anchor + notchMessageExtra, 520), height: 300)
        }
    }

    private func startTimeout(seconds: Double) {
        cancelTimeout()
        timeoutProgress = 0
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
