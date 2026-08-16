import Foundation
import Observation

@MainActor
@Observable
final class AppContainer {

    static let shared = AppContainer()

    let prefs: PreferencesStore
    let memory: HabitMemoryStore
    let brain: PerchBrain
    let personality: PersonalityEngine
    let tracker: FocusSessionTracker
    let calendar: CalendarAwarenessService
    let voice: VoiceService
    let music: BreakMusicService
    let notifications: NotificationService
    let subscriptions: SubscriptionManager
    let engine: ReminderEngine
    let coordinator: CompanionCoordinator
    let shortcuts: QuickAnswerShortcutManager

    private init() {
        let prefs = PreferencesStore()
        let memory = HabitMemoryStore()
        let brain = PerchBrain()
        let subscriptions = SubscriptionManager()
        let personality = PersonalityEngine(prefs: prefs)
        let tracker = FocusSessionTracker(prefs: prefs, memory: memory)
        let calendar = CalendarAwarenessService()
        let voice = VoiceService(prefs: prefs)
        let music = BreakMusicService(prefs: prefs)
        let notifications = NotificationService(prefs: prefs)
        let engine = ReminderEngine(
            prefs: prefs,
            memory: memory,
            tracker: tracker,
            calendar: calendar,
            subscriptions: subscriptions
        )
        let coordinator = CompanionCoordinator(
            prefs: prefs,
            memory: memory,
            personality: personality,
            voice: voice,
            music: music,
            notifications: notifications,
            tracker: tracker,
            subscriptions: subscriptions,
            brain: brain
        )
        let shortcuts = QuickAnswerShortcutManager(prefs: prefs)

        self.prefs = prefs
        self.memory = memory
        self.brain = brain
        self.subscriptions = subscriptions
        self.personality = personality
        self.tracker = tracker
        self.calendar = calendar
        self.voice = voice
        self.music = music
        self.notifications = notifications
        self.engine = engine
        self.coordinator = coordinator
        self.shortcuts = shortcuts

        engine.onDeliver = { [weak coordinator] kind, context in
            await coordinator?.present(kind: kind, context: context) ?? false
        }
        engine.isPresenting = { [weak coordinator] in
            coordinator?.isPresenting ?? false
        }
        coordinator.applyResponse = { [weak engine] kind, response, context in
            engine?.applyResponse(kind: kind, response: response, context: context)
        }
        coordinator.presentBreakOverlay = { [weak self] seconds, onComplete in
            guard let self else { return }
            WindowPresenter.shared.showBreakOverlay(self, seconds: seconds, onComplete: onComplete)
        }
        shortcuts.onPressed = { [weak coordinator] in
            coordinator?.quickAnswerPressed()
        }

        memory.onWaterLogged = { [weak brain] in brain?.recordWater() }
        memory.onBreakTaken = { [weak brain] in brain?.recordBreak() }
        memory.onMealLogged = { [weak brain] in brain?.recordMeal() }
        memory.onShowerLogged = { [weak brain] in brain?.recordShower() }
        memory.onResponseRecorded = { [weak brain, weak memory] in
            guard let brain, let memory else { return }
            let patterns = memory.learnedPatterns()
            brain.updateResponsePatterns(wellTo: patterns.wellTo, ignores: patterns.ignores)
        }
        tracker.onRunEnded = { [weak brain] seconds in brain?.recordFocusSeconds(seconds) }
    }

    func start() {
        coordinator.prepare()
        engine.start()
        shortcuts.registerFromPrefs()
        calendar.start()
        brain.setUserName(prefs.userName)
        watchTrialExpiry()
    }

    /// Perch is a menu bar app that can stay running across the trial's end;
    /// this catches that moment and forces the paywall without waiting for
    /// the next launch.
    private func watchTrialExpiry() {
        Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 60_000_000_000)
                guard let self else { return }
                if self.prefs.hasOnboarded {
                    WindowPresenter.shared.enforcePaywallIfLocked(self)
                }
            }
        }
    }
}
