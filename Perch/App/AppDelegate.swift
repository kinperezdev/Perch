import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.appearance = NSAppearance(named: .darkAqua)
        let container = AppContainer.shared
        container.start()
        routeInitialWindow(container)

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                AppContainer.shared.coordinator.handleScreenChange()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        routeInitialWindow(AppContainer.shared)
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppContainer.shared.memory.flush()
        AppContainer.shared.brain.flush()
        AppContainer.shared.shortcuts.unregister()
    }

    /// Onboarding first, then the free trial gates everything: once it runs
    /// out with no purchase, every launch/reopen lands on a paywall the user
    /// can't dismiss instead of the dashboard.
    private func routeInitialWindow(_ container: AppContainer) {
        guard container.prefs.hasOnboarded else {
            WindowPresenter.shared.showOnboarding(container)
            return
        }
        if container.subscriptions.isLocked {
            WindowPresenter.shared.showPaywall(container, dismissable: false)
        } else {
            WindowPresenter.shared.showDashboard(container)
        }
    }
}
