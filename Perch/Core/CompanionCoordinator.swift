import Foundation
import Observation
import SwiftUI

/// Drives everything the user sees in the notch bubble: check ins,
@MainActor
@Observable
final class CompanionCoordinator {

    enum Phase: Equatable {
        case hidden
        case message
        case listening
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

    var applyResponse: ((ReminderKind, CheckInResponse) -> Void)?

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

    /// Called once by the container after init so the panel view can hold self.
    func prepare() {
        panel.attach(NotchCompanionView(coordinator: self))
    }

    var accentColors: [Color] { personality.activePersonality.accentColors }
    var activePersonality: Personality { personality.activePersonality }
    var companionName: String { personality.companionName }
    var gate: FeatureGate { subscriptions.gate }
    var isPresenting: Bool { phase != .hidden }
    var voiceTranscript: String { voice.transcript }
    var isVoiceListening: Bool { voice.isListening }

    // MARK: Presenting

    /// Engine entry point. Returns false when something is already showing.
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
        if isTracked(kind) {
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

    // MARK: Responding

    func respond(_ response: CheckInResponse) {
        guard let current, phase == .message || phase == .listening else { return }
        cancelTimeout()
        voice.stopListening(deliver: false)
        lastCheckInAnswered = true
        if isTracked(current.kind) {
            applyResponse?(current.kind, response)
        }
        if response.isPositive {
            brain.recordPositiveResponse(kind: current.kind.rawValue)
        }
        showConfirmation(personality.confirmation(for: response))
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
        if isTracked(current.kind) {
            applyResponse?(current.kind, completed ? .timerCompleted : .done)
        }
        showConfirmation(personality.confirmation(for: .timerCompleted))
    }

    func startVoiceReply() {
        guard subscriptions.gate.voiceInteraction, phase == .message else { return }
        cancelTimeout()
        Task { [weak self] in
            guard let self else { return }
            guard await self.voice.requestListeningPermissions() else {
                self.startTimeout(seconds: 15)
                return
            }
            self.reveal(.listening)
            self.voice.startListening { [weak self] transcript in
                guard let self else { return }
                if let response = VoiceService.interpret(transcript) {
                    self.respond(response)
                } else {
                    self.showConfirmation(transcript.isEmpty ? "All good. I'm here." : "Got it. I'll leave you to it.")
                }
            }
        }
    }

    // MARK: Quick actions used by the status bubble and menu bar

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

    // MARK: Quick answer shortcut

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
        case .listening, .timer:
            break
        }
    }

    /// Mic shortcut: talk to Perch by voice from anywhere.
    func micPressed() {
        switch phase {
        case .message:
            startVoiceReply()
        case .listening:
            voice.stopListening(deliver: true)
        case .chat:
            toggleChatVoiceMessage()
        case .hidden:
            openChat()
            toggleChatVoiceMessage()
        case .timer, .confirmation:
            break
        }
    }

    private func toggleChatVoiceMessage() {
        if voice.isListening {
            voice.stopListening(deliver: true)
            return
        }
        guard subscriptions.gate.voiceInteraction else { return }
        Task { [weak self] in
            guard let self else { return }
            guard await self.voice.requestListeningPermissions() else { return }
            self.voice.startListening { [weak self] transcript in
                guard let self, !transcript.isEmpty else { return }
                self.chat.send(transcript)
            }
        }
    }

    private func represent(_ checkIn: CheckIn) {
        current = checkIn
        reveal(.message)
        panel.makeKey()
        startTimeout(seconds: 30)
    }

    // MARK: Chat

    func openChat() {
        cancelTimeout()
        chat.openIfNeeded()
        reveal(.chat)
        panel.makeKey()
    }

    func startChatDictation(onText: @escaping (String) -> Void) {
        guard subscriptions.gate.voiceInteraction else { return }
        Task { [weak self] in
            guard let self else { return }
            guard await self.voice.requestListeningPermissions() else { return }
            self.voice.startListening { transcript in
                if !transcript.isEmpty { onText(transcript) }
            }
        }
    }

    // MARK: Visibility

    func hide() {
        cancelTimeout()
        timerTask?.cancel()
        voice.stopListening(deliver: false)
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
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            guard !Task.isCancelled, self?.phase == .confirmation else { return }
            self?.hide()
        }
    }

    private static func size(for phase: Phase, metrics: NotchMetrics) -> CGSize {
        let anchor: CGFloat = metrics.hasNotch ? metrics.notchWidth : 185
        switch phase {
        case .hidden, .listening:
            return CGSize(width: max(anchor + 40, 250), height: 132)
        case .message, .chat:
            return CGSize(width: max(anchor + 240, 440), height: phase == .chat ? 300 : 140)
        case .timer:
            return CGSize(width: max(anchor - 20, 235), height: 94)
        case .confirmation:
            return CGSize(width: max(anchor - 40, 210), height: 58)
        case .chat:
            return CGSize(width: max(anchor + 240, 440), height: 300)
        }
    }

    // MARK: Timeout

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
            if let current = self.current, self.isTracked(current.kind) {
                self.applyResponse?(current.kind, .timedOut)
            }
            self.hide()
        }
    }

    private func cancelTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
        timeoutProgress = 0
    }

    private func isTracked(_ kind: ReminderKind) -> Bool {
        kind != .status && kind != .welcome && kind != .sessionStart
    }
}
