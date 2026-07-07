import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationDidFinishLaunching(_ notification: Notification) {
        let container = AppContainer.shared
        container.start()

        if container.prefs.hasOnboarded {
            WindowPresenter.shared.showDashboard(container)
        } else {
            WindowPresenter.shared.showOnboarding(container)
        }

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
        let container = AppContainer.shared
        if container.prefs.hasOnboarded {
            WindowPresenter.shared.showDashboard(container)
        } else {
            WindowPresenter.shared.showOnboarding(container)
        }
        return false
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppContainer.shared.memory.flush()
        AppContainer.shared.brain.flush()
        AppContainer.shared.shortcuts.unregister()
    }
}
