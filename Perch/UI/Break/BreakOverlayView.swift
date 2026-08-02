import SwiftUI

struct BreakOverlayView: View {
    @Environment(AppContainer.self) private var container
    var onEnd: () -> Void

    @State private var remaining: Int
    @State private var total: Int
    @State private var timerTask: Task<Void, Never>?
    @State private var notePulse = false

    init(onEnd: @escaping () -> Void) {
        self.onEnd = onEnd
        let seconds = ReminderKind.walk.timerSeconds
        _remaining = State(initialValue: seconds)
        _total = State(initialValue: seconds)
    }

    private var accent: [Color] { container.prefs.activePersonality.accentColors }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            SkyLayer(isNight: true, condition: .clear)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Spacer()
                CompanionFaceView(
                    state: .playing,
                    accent: accent,
                    size: 130,
                    personality: container.prefs.activePersonality,
                    glows: false
                )
                Text("\(container.personality.companionName) is taking five with you")
                    .font(.perchRounded(17, weight: .semibold))
                    .foregroundStyle(.white)
                Text(timeString)
                    .font(.system(size: 54, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                HStack(spacing: 6) {
                    Image(systemName: "music.note")
                        .opacity(notePulse ? 1 : 0.35)
                    Text("Lofi playing")
                }
                .font(.perchRounded(12))
                .foregroundStyle(.white.opacity(0.6))
                Spacer()
                Button("End break early") { finish() }
                    .buttonStyle(.glass)
                    .tint(.white)
                    .padding(.bottom, 44)
            }
        }
        .task { start() }
        .onExitCommand { finish() }
    }

    private var timeString: String {
        String(format: "%d:%02d", remaining / 60, remaining % 60)
    }

    private func start() {
        container.tracker.beginRest()
        container.music.start()
        withAnimation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true)) {
            notePulse = true
        }
        timerTask?.cancel()
        timerTask = Task {
            while remaining > 0, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard !Task.isCancelled else { return }
                remaining -= 1
            }
            guard !Task.isCancelled else { return }
            finish()
        }
    }

    private func finish() {
        timerTask?.cancel()
        container.music.stop()
        container.tracker.endRest()
        onEnd()
    }
}
