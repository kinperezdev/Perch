import AppKit
import SwiftUI

/// Presents the few real windows Perch has: onboarding,
@MainActor
final class WindowPresenter {

    static let shared = WindowPresenter()
    private var windows: [String: NSWindow] = [:]

    func showOnboarding(_ container: AppContainer) {
        show(id: "onboarding", size: NSSize(width: 700 * PerchStyle.scale, height: 560 * PerchStyle.scale)) {
            OnboardingView(onFinish: { [weak self] in
                self?.close(id: "onboarding")
                container.coordinator.showWelcome()
            })
            .environment(container)
        }
    }

    func showPaywall(_ container: AppContainer) {
        show(id: "paywall", size: NSSize(width: 440 * PerchStyle.scale, height: 640 * PerchStyle.scale)) {
            PerchPaywallView(onClose: { [weak self] in
                self?.close(id: "paywall")
            })
            .environment(container)
        }
    }

    func showCustomerCenter(_ container: AppContainer) {
        show(id: "customercenter", size: NSSize(width: 440 * PerchStyle.scale, height: 300 * PerchStyle.scale)) {
            CustomerCenterHost().environment(container)
        }
    }

    func showWeeklySummary(_ container: AppContainer) {
        show(id: "summary", size: NSSize(width: 460 * PerchStyle.scale, height: 520 * PerchStyle.scale)) {
            WeeklySummaryView().environment(container)
        }
    }

    func showDashboard(_ container: AppContainer) {
        show(id: "dashboard", size: NSSize(width: 720 * PerchStyle.scale, height: 560 * PerchStyle.scale)) {
            DashboardView().environment(container)
        }
    }
    func showSettings(_ container: AppContainer) {
        showStandardWindow(id: "settings", size: NSSize(width: 640 * PerchStyle.scale, height: 520 * PerchStyle.scale)) {
            SettingsView().environment(container)
        }
    }

    // MARK: Private

    private func showStandardWindow<Content: View>(id: String, size: NSSize, @ViewBuilder content: () -> Content) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content().environment(\.dynamicTypeSize, .medium))
        window.center()
        windows[id] = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.windows.removeValue(forKey: id)
            }
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func show<Content: View>(id: String, size: NSSize, @ViewBuilder content: () -> Content) {
        if let existing = windows[id] {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: content().environment(\.dynamicTypeSize, .medium))
        window.center()
        windows[id] = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { _ in
            Task { @MainActor [weak self] in
                self?.windows.removeValue(forKey: id)
            }
        }
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }

    private func close(id: String) {
        windows[id]?.close()
    }
}
