import AppKit
import SwiftUI
import QuartzCore

struct NotchMetrics: Equatable {
    var hasNotch = false
    var topInset: CGFloat = 26
    var notchWidth: CGFloat = 200
}

final class NotchPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

@MainActor
final class NotchPanelController {

    private var panel: NotchPanel?
    private var hideTask: Task<Void, Never>?
    private(set) var metrics = NotchMetrics()

    func attach<Content: View>(_ content: Content) {
        guard panel == nil else { return }
        let panel = NotchPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 180),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.isReleasedWhenClosed = false
        panel.animationBehavior = .none
        panel.becomesKeyOnlyIfNeeded = true

        let hosting = NSHostingView(rootView: content.environment(\.dynamicTypeSize, .medium))
        hosting.frame = panel.contentLayoutRect
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting
        self.panel = panel
    }

    @discardableResult
    func refreshMetrics() -> NotchMetrics {
        metrics = Self.metrics(for: Self.targetScreen())
        return metrics
    }

    @discardableResult
    func show(width: CGFloat, contentHeight: CGFloat) -> NotchMetrics {
        hideTask?.cancel()
        guard let panel else { return metrics }
        let screen = Self.targetScreen()
        metrics = Self.metrics(for: screen)

        let height = metrics.topInset + contentHeight
        let frame = NSRect(
            x: screen.frame.midX - width / 2,
            y: screen.frame.maxY - height,
            width: width,
            height: height
        )
        if panel.isVisible {
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.22
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                panel.animator().setFrame(frame, display: true)
            }
        } else {
            panel.setFrame(frame, display: true)
            panel.orderFrontRegardless()
        }
        return metrics
    }

    func hide(afterDelay delay: Double) {
        hideTask?.cancel()
        hideTask = Task { [weak panel] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            panel?.orderOut(nil)
        }
    }

    func makeKey() {
        panel?.makeKey()
    }

        // MARK: Screen math

    private static func targetScreen() -> NSScreen {
        NSScreen.screens.first { $0.safeAreaInsets.top > 0 }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private static func metrics(for screen: NSScreen) -> NotchMetrics {
        let inset = screen.safeAreaInsets.top
        if inset > 0 {
            var notchWidth: CGFloat = 200
            if let left = screen.auxiliaryTopLeftArea, let right = screen.auxiliaryTopRightArea {
                notchWidth = screen.frame.width - left.width - right.width
            }
            return NotchMetrics(hasNotch: true, topInset: inset, notchWidth: notchWidth)
        }
        let menuBar = screen.frame.maxY - screen.visibleFrame.maxY
        return NotchMetrics(hasNotch: false, topInset: min(max(menuBar, 22), 40), notchWidth: 0)
    }
}
