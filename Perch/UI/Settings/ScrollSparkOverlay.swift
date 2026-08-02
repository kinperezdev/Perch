import AppKit
import SwiftUI

struct ScrollSparkOverlay: View {
    @State private var sparks: [Spark] = []
    @State private var monitor: Any?
    @State private var progress: CGFloat = 0
    @State private var lastSpawnAt: Date = .distantPast

    private struct Spark: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        var goingDown: Bool
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                ForEach(sparks) { spark in
                    SparkGlyph(goingDown: spark.goingDown)
                        .position(x: spark.x, y: spark.y)
                }
            }
            .onAppear { startMonitoring(size: geo.size) }
            .onDisappear(perform: stopMonitoring)
        }
        .allowsHitTesting(false)
    }

    private func startMonitoring(size: CGSize) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            spawnSpark(deltaY: event.scrollingDeltaY, size: size)
            return event
        }
    }

    private func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func spawnSpark(deltaY: CGFloat, size: CGSize) {
        guard abs(deltaY) > 0.5, size.height > 0 else { return }
        guard let contentView = NSApp.keyWindow?.contentView, hasVisibleVerticalScrollbar(in: contentView) else { return }
        let scrollingDown = deltaY < 0
        let trackTop: CGFloat = 20
        let trackHeight = max(size.height - 40, 1)
        progress = min(max(progress - deltaY / 2400, 0), 1)

        let now = Date()
        guard now.timeIntervalSince(lastSpawnAt) > 0.12 else { return }
        lastSpawnAt = now

        let scrollbarX = size.width - 6
        let thumbY = trackTop + progress * trackHeight
        let tipOffset: CGFloat = scrollingDown ? 8 : -8
        let spark = Spark(
            x: scrollbarX + CGFloat.random(in: -3...1),
            y: thumbY + tipOffset,
            goingDown: scrollingDown
        )
        sparks.append(spark)
        let id = spark.id
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            sparks.removeAll { $0.id == id }
        }
        if sparks.count > 12 {
            sparks.removeFirst(sparks.count - 12)
        }
    }

    private func hasVisibleVerticalScrollbar(in view: NSView) -> Bool {
        if let scroller = view as? NSScroller, scroller.bounds.height > scroller.bounds.width {
            return !scroller.isHidden && scroller.knobProportion < 0.999
        }
        for subview in view.subviews where hasVisibleVerticalScrollbar(in: subview) {
            return true
        }
        return false
    }
}

private struct SparkGlyph: View {
    let goingDown: Bool
    @State private var animate = false

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(.white.opacity(animate ? 0 : 0.9))
            .offset(y: animate ? (goingDown ? 10 : -10) : 0)
            .scaleEffect(animate ? 0.3 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.45)) { animate = true }
            }
    }
}
