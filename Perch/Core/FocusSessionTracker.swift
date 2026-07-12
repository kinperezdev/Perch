import AppKit
import CoreGraphics
import Foundation
import Observation

@MainActor
@Observable
final class FocusSessionTracker {

    private(set) var focusRunSeconds: Double = 0
    private(set) var idleSeconds: Double = 0
    private(set) var lastBreakAt: Date?
    private(set) var isScreenLocked = false

    @ObservationIgnored private let prefs: PreferencesStore
    @ObservationIgnored private let memory: HabitMemoryStore

    @ObservationIgnored var onRunEnded: ((Double) -> Void)?

    init(prefs: PreferencesStore, memory: HabitMemoryStore) {
        self.prefs = prefs
        self.memory = memory
        observeSystemState()
    }

    var focusRunMinutes: Int { Int(focusRunSeconds / 60) }
    var isInSession: Bool { focusRunSeconds > 60 }
    var todayActiveSeconds: Double { memory.today().activeSeconds }

    func update(delta realDelta: Double) {
        guard !isScreenLocked else {
            endRun()
            return
        }
        idleSeconds = Self.systemIdleSeconds()

        if idleSeconds < Self.activeThreshold {
            let scaled = realDelta * prefs.demoTimeScale
            focusRunSeconds += scaled
            memory.addActive(seconds: scaled)
            if prefs.isAfterWorkHours() {
                memory.addOverwork(seconds: scaled)
            }
        } else if idleSeconds >= Self.naturalBreakThreshold {
            endRun()
        }
    }

    func creditBreak() {
        lastBreakAt = Date()
        reportRunEnded()
        focusRunSeconds = 0
        memory.creditBreak()
    }

        // MARK: Private

    private static let activeThreshold: Double = 90
    private static let naturalBreakThreshold: Double = 300

    private func endRun() {
        if focusRunSeconds > 120 {
            lastBreakAt = Date()
            reportRunEnded()
            memory.creditBreak()
        }
        focusRunSeconds = 0
    }

    private func reportRunEnded() {
        guard focusRunSeconds > 120 else { return }
        onRunEnded?(focusRunSeconds)
    }

    private func observeSystemState() {
        let distributed = DistributedNotificationCenter.default()
        distributed.addObserver(forName: .init("com.apple.screenIsLocked"), object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.isScreenLocked = true }
        }
        distributed.addObserver(forName: .init("com.apple.screenIsUnlocked"), object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.isScreenLocked = false }
        }
        let workspace = NSWorkspace.shared.notificationCenter
        workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in
                self?.isScreenLocked = true
                self?.endRun()
            }
        }
        workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.isScreenLocked = false }
        }
        workspace.addObserver(forName: NSWorkspace.screensDidSleepNotification, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in
                self?.isScreenLocked = true
                self?.endRun()
            }
        }
        workspace.addObserver(forName: NSWorkspace.screensDidWakeNotification, object: nil, queue: .main) { _ in
            Task { @MainActor [weak self] in self?.isScreenLocked = false }
        }
    }

    private static func systemIdleSeconds() -> Double {
        let types: [CGEventType] = [
            .mouseMoved, .keyDown, .leftMouseDown, .rightMouseDown,
            .scrollWheel, .otherMouseDown, .leftMouseDragged,
        ]
        let values = types.map {
            CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0)
        }
        return values.min() ?? 0
    }
}
