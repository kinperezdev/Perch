import AppKit
import SwiftUI

struct ScrollSparkOverlay: View {
    @State private var sparks: [Spark] = []
    @State private var monitor: Any?

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
            .onAppear { startMonitoring(width: geo.size.width) }
            .onDisappear(perform: stopMonitoring)
        }
        .allowsHitTesting(false)
    }

    private func startMonitoring(width: CGFloat) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { event in
            spawnSpark(deltaY: event.scrollingDeltaY, width: width)
            return event
        }
    }

    private func stopMonitoring() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    private func spawnSpark(deltaY: CGFloat, width: CGFloat) {
        guard abs(deltaY) > 0.5 else { return }
        let spark = Spark(
            x: width - CGFloat.random(in: 6...16),
            y: CGFloat.random(in: 40...320),
            goingDown: deltaY < 0
        )
        sparks.append(spark)
        let id = spark.id
        Task {
            try? await Task.sleep(for: .seconds(0.5))
            sparks.removeAll { $0.id == id }
        }
        if sparks.count > 24 {
            sparks.removeFirst(sparks.count - 24)
        }
    }
}

private struct SparkGlyph: View {
    let goingDown: Bool
    @State private var animate = false

    var body: some View {
        Image(systemName: "sparkle")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(.white.opacity(animate ? 0 : 0.85))
            .offset(y: animate ? (goingDown ? 14 : -14) : 0)
            .scaleEffect(animate ? 0.4 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.5)) { animate = true }
            }
    }
}
