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
        show(id: "paywall", size: NSSize(width: 440 * PerchStyle.scale, height: 560 * PerchStyle.scale)) {
            PerchPaywallView(onClose: { [weak self] in
                self?.close(id: "paywall")
            })
            .environment(container)
        }
    }

    func showDashboard(_ container: AppContainer) {
        show(id: "dashboard", size: NSSize(width: 720 * PerchStyle.scale, height: 510 * PerchStyle.scale)) {
            DashboardView().environment(container)
        }
    }
    func showSettings(_ container: AppContainer) {
        showStandardWindow(id: "settings", size: NSSize(width: 640 * PerchStyle.scale, height: 520 * PerchStyle.scale)) {
            SettingsView().environment(container)
        }
    }

    private static let breakOverlayID = "breakOverlay"

    func showBreakOverlay(_ container: AppContainer) {
        guard windows[Self.breakOverlayID] == nil else { return }
        guard let screen = NSScreen.main else { return }
        let window = NSWindow(
            contentRect: screen.frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = true
        window.backgroundColor = .black
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.delegate = self
        window.contentView = NSHostingView(
            rootView: BreakOverlayView(onEnd: { [weak self] in self?.closeBreakOverlay() })
                .environment(container)
                .environment(\.dynamicTypeSize, .medium)
        )
        window.setFrame(screen.frame, display: true)
        windows[Self.breakOverlayID] = window
        NSApp.presentationOptions = [.hideDock, .hideMenuBar]
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
    }

    func closeBreakOverlay() {
        NSApp.presentationOptions = []
        close(id: Self.breakOverlayID)
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
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "Settings"
        window.titlebarAppearsTransparent = true
        window.titlebarSeparatorStyle = .none
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(hex: 0x0B0B0E)
        window.collectionBehavior.remove(.fullScreenPrimary)
        window.maxSize = NSSize(width: 960, height: 760)
        window.standardWindowButton(.zoomButton)?.isEnabled = false
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.contentView = NSHostingView(rootView: content().environment(\.dynamicTypeSize, .medium))
        window.contentView?.wantsLayer = true
        window.contentView?.layer?.backgroundColor = NSColor(hex: 0x0B0B0E).cgColor
        window.center()
        windows[id] = window
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        DispatchQueue.main.async {
            self.flattenVibrancy(in: window, color: NSColor(hex: 0x0B0B0E))
        }
    }

    private func flattenVibrancy(in window: NSWindow, color: NSColor) {
        guard let themeFrame = window.contentView?.superview else { return }
        flattenVibrancy(in: themeFrame, color: color)
    }

    private func flattenVibrancy(in view: NSView, color: NSColor) {
        if let effectView = view as? NSVisualEffectView {
            effectView.blendingMode = .withinWindow
            effectView.wantsLayer = true
            effectView.layer?.backgroundColor = color.cgColor
        }
        for subview in view.subviews {
            flattenVibrancy(in: subview, color: color)
        }
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
