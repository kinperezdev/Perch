import AppKit
import SwiftUI

@MainActor
final class WindowPresenter: NSObject, NSWindowDelegate {

    static let shared = WindowPresenter()
    private var windows: [String: NSWindow] = [:] {
        didSet { updateActivationPolicy() }
    }

    private func updateActivationPolicy() {
        if windows.isEmpty {
            NSApp.setActivationPolicy(.accessory)
        } else {
            NSApp.setActivationPolicy(.regular)
        }
    }

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
        show(id: "dashboard", size: NSSize(width: 720 * PerchStyle.scale, height: 580 * PerchStyle.scale)) {
            DashboardView().environment(container)
        }
    }
    func showSettings(_ container: AppContainer) {
        showStandardWindow(id: "settings", size: NSSize(width: 640 * PerchStyle.scale, height: 520 * PerchStyle.scale)) {
            SettingsView().environment(container)
        }
    }

    private func showStandardWindow<Content: View>(id: String, size: NSSize, @ViewBuilder content: () -> Content) {
        if let existing = windows[id] {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
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
        window.delegate = self
        window.contentView = NSHostingView(rootView: content().environment(\.dynamicTypeSize, .medium))
        window.center()
        windows[id] = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func show<Content: View>(id: String, size: NSSize, @ViewBuilder content: () -> Content) {
        if let existing = windows[id] {
            NSApp.activate(ignoringOtherApps: true)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
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
        window.delegate = self
        window.contentView = NSHostingView(rootView: content().environment(\.dynamicTypeSize, .medium))
        window.center()
        windows[id] = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    private func close(id: String) {
        windows[id]?.close()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow else { return }
        if let id = windows.first(where: { $0.value === window })?.key {
            windows.removeValue(forKey: id)
        }
    }
}
