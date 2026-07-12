import SwiftUI

struct NotchCompanionView: View {
    let coordinator: CompanionCoordinator
    @Environment(PreferencesStore.self) private var prefs

    private var accent: [Color] { coordinator.accentColors }

    var body: some View {
        ZStack(alignment: .top) {
            if coordinator.phase != .hidden {
                bubble
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(.spring(response: 0.45, dampingFraction: 0.82), value: coordinator.phase)
    }

        // MARK: Bubble chrome

    private var bubble: some View {
        let metrics = coordinator.metrics
        let shape = UnevenRoundedRectangle(
            cornerRadii: .init(
                topLeading: metrics.hasNotch ? 0 : 20,
                bottomLeading: PerchStyle.bubbleRadius,
                bottomTrailing: PerchStyle.bubbleRadius,
                topTrailing: metrics.hasNotch ? 0 : 20
            ),
            style: .continuous
        )
        return VStack(spacing: 0) {
            content
            if coordinator.phase == .message {
                waitingFooter.padding(.top, 7)
                timeoutBar.padding(.top, 5)
            }
        }
        .padding(.top, topPadding(for: metrics))
        .padding(.horizontal, 12)
        .padding(.bottom, 9)
        .frame(maxWidth: .infinity)
        .background(shape.fill(Color(red: 0, green: 0, blue: 0)))
        .compositingGroup()
        .padding(.top, metrics.hasNotch ? 0 : 6)
        .onHover { coordinator.isHovering = $0 }
    }

    private func topPadding(for metrics: NotchMetrics) -> CGFloat {
        guard metrics.hasNotch else { return 10 }
        switch coordinator.phase {
        case .timer, .confirmation:
            return 0
        default:
            return 4
        }
    }

    @ViewBuilder
    private var content: some View {
        switch coordinator.phase {
        case .hidden:
            EmptyView()
        case .message:
            if let checkIn = coordinator.current { messageView(checkIn) }
        case .timer:
            timerView
        case .confirmation:
            confirmationView
        case .chat:
            CompanionChatView(coordinator: coordinator)
        }
    }

        // MARK: Message

    private func faceState(for checkIn: CheckIn) -> CompanionFaceView.FaceState {
        let fallback: CompanionFaceView.FaceState
        switch checkIn.kind {
        case .overwork, .windDown: fallback = .concerned
        case .sleep: fallback = .sleepy
        case .welcome, .sessionStart: fallback = .excited
        case .status: fallback = .happy
        default: fallback = .talking
        }
        return CompanionFaceView.FaceState.inferred(from: checkIn.message, fallback: fallback)
    }

    private func messageView(_ checkIn: CheckIn) -> some View {
        let metrics = coordinator.metrics
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    CompanionFaceView(state: faceState(for: checkIn), accent: accent, size: 26)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if metrics.hasNotch {
                    Color.clear.frame(width: metrics.notchWidth + 12, height: 1)
                }

                HStack(spacing: 6) {
                    logMenu
                    dismissButton(for: checkIn)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: metrics.hasNotch ? max(metrics.topInset - 6, 26) : 28)
            .padding(.horizontal, 4)

            VStack(spacing: 8) {
                Text(checkIn.message)
                    .font(.perchRounded(12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.94))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 6)

                HStack(spacing: 6) {
                    leftActions(for: checkIn)
                    rightActions(for: checkIn)
                }
            }
            .padding(.horizontal, 6)
        }
        .padding(.bottom, 4)
    }

    private var logMenu: some View {
        let log = coordinator.todayLog
        return Menu {
            Button { coordinator.quickLog(.water) } label: { Label("Log water (\(log.waterCount))", systemImage: "drop.fill") }
            Button { coordinator.quickLog(.meal) } label: { Label("Log a meal (\(log.mealsLogged))", systemImage: "fork.knife") }
            Button { coordinator.quickLog(.breakTime) } label: { Label("Took a break (\(log.breaksTaken))", systemImage: "figure.walk") }
            Button { coordinator.quickLog(.shower) } label: { Label("Showered\(log.showerLogged ? " (Yes)" : "")", systemImage: "shower.fill") }
        } label: {
            Image(systemName: "plus")
        }
        .menuStyle(.button)
        .buttonStyle(IconPillButtonStyle())
        .menuIndicator(.hidden)
        .fixedSize()
        .help("Log a habit without answering")
    }

    private func dismissButton(for checkIn: CheckIn) -> some View {
        Button {
            if checkIn.kind == .status || checkIn.kind == .welcome || checkIn.kind == .sessionStart {
                coordinator.hide()
            } else {
                coordinator.respond(.ignored)
            }
        } label: {
            Image(systemName: "xmark")
        }
        .buttonStyle(IconPillButtonStyle())
        .keyboardShortcut(.cancelAction)
    }

    @ViewBuilder
    private func leftActions(for checkIn: CheckIn) -> some View {
        switch checkIn.kind {
        case .status:
            Button(action: { coordinator.respondMood(.stressed) }) { Text("Stressing") }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("3", modifiers: [])
            Button(action: { coordinator.respondMood(.okay) }) { Text("Am okay") }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("2", modifiers: [])
        case .welcome:
            Button(action: { coordinator.respond(.snoozed(minutes: 10)) }) { Text("In a bit") }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("2", modifiers: [])
            Button(action: { coordinator.respond(.ignored) }) { Text("Just chilling") }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("3", modifiers: [])
        case .sessionStart:
            Button(action: { coordinator.respond(.ignored) }) { Text("Later") }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("3", modifiers: [])
            Button(action: { coordinator.respond(.snoozed(minutes: 10)) }) { Text("Not yet") }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("2", modifiers: [])
        case .meal, .water, .shower, .sleep, .routine:
            Button(action: { coordinator.respond(.snoozed(minutes: 10)) }) { Text("Later") }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("3", modifiers: [])
            Button(action: { coordinator.respond(.ignored) }) { Text("Not yet") }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("2", modifiers: [])
        default:
            if checkIn.kind.supportsThanks && !checkIn.message.contains("?") {
                Button(action: { coordinator.respondThanks() }) { Text("Thanks") }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("4", modifiers: [])
            }
                Button(action: { coordinator.respond(.snoozed(minutes: 10)) }) { Text("Later") }
            .buttonStyle(GhostPillButtonStyle())
            .keyboardShortcut("3", modifiers: [])
        }
    }

    @ViewBuilder
    private func rightActions(for checkIn: CheckIn) -> some View {
        switch checkIn.kind {
        case .status:
            Button(action: { coordinator.respondMood(.great) }) { Text("Good") }
                .buttonStyle(PillButtonStyle(accent: accent))
                .keyboardShortcut("1", modifiers: [])
        case .welcome:
            Button(action: { coordinator.respond(.done) }) { Text("Let's go") }
                .buttonStyle(PillButtonStyle(accent: accent))
                .keyboardShortcut("1", modifiers: [])
        case .sessionStart:
            let isNowQuestion = checkIn.message.contains("Starting another session") || checkIn.message.contains("locking in") || checkIn.message.contains("Starting a focus session") || checkIn.message.contains("Ready") || checkIn.message.contains("Starting focus now")
            Button(action: { coordinator.respond(.done) }) { Text(isNowQuestion ? "Sure" : "Okay") }
                .buttonStyle(PillButtonStyle(accent: accent))
                .keyboardShortcut("1", modifiers: [])
        default:
            if checkIn.kind.supportsTimer {
                Button {
                    coordinator.startTimer()
                } label: {
                    let seconds = checkIn.computedTimerSeconds(prefs: prefs)
                    if seconds < 60 {
                        Text("Start \(seconds)s")
                    } else {
                        Text("Start \(seconds / 60)m")
                    }
                }
                .buttonStyle(PillButtonStyle(accent: accent))
                .keyboardShortcut("1", modifiers: [])
            } else {
                Button(action: { coordinator.respond(.done) }) { Text(checkIn.kind.primaryActionLabel) }
                .buttonStyle(PillButtonStyle(accent: accent))
                .keyboardShortcut("1", modifiers: [])
            }
        }
    }

    private func keycap(_ label: String, dark: Bool) -> some View {
        Text(label)
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .foregroundStyle(dark ? .black.opacity(0.55) : .white.opacity(0.6))
            .frame(width: 12, height: 12)
            .background(
                dark ? Color.black.opacity(0.14) : Color.white.opacity(0.14),
                in: RoundedRectangle(cornerRadius: 3, style: .continuous)
            )
    }

    private var waitingFooter: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 20.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.4 + 0.5 * (0.5 + 0.5 * sin(t * 3))
            HStack(spacing: 5) {
                Circle()
                    .fill(accent[0])
                    .frame(width: 4, height: 4)
                    .opacity(pulse)
                Text("Waiting for your reply")
                    .font(.system(size: 9, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.42))
                Spacer()
            }
        }
    }

    private var timeoutBar: some View {
        GeometryReader { geo in
            Capsule()
                .fill(accent[0].opacity(0.45))
                .frame(width: max(geo.size.width * (1 - coordinator.timeoutProgress), 0), height: 2)
        }
        .frame(height: 2)
    }

        // MARK: Timer

    private var timerView: some View {
        let metrics = coordinator.metrics
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                HStack {
                    ZStack {
                        Circle()
                            .stroke(.white.opacity(0.12), lineWidth: 3)
                        Circle()
                            .trim(from: 0, to: CGFloat(coordinator.timerRemaining) / CGFloat(max(coordinator.timerTotal, 1)))
                            .stroke(
                                LinearGradient(colors: accent, startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 3, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 1), value: coordinator.timerRemaining)
                        Text(timerLabel)
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                    }
                    .frame(width: 28, height: 28)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if metrics.hasNotch {
                    Color.clear.frame(width: metrics.notchWidth + 12, height: 1)
                }

                HStack {
                    Button("Finish") { coordinator.finishTimer(completed: false) }
                        .buttonStyle(GhostPillButtonStyle())
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: metrics.hasNotch ? max(metrics.topInset - 6, 26) : 28)
            .padding(.horizontal, 4)

            VStack(alignment: .center, spacing: 5) {
                Text("Rest in progress")
                    .font(.perchRounded(13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text("Move a little. I'll keep count.")
                    .font(.perchRounded(11))
                    .foregroundStyle(.white.opacity(0.5))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                
                CompanionFaceView(state: .playing, accent: accent, size: 28)
                    .padding(.top, 4)
            }
            .padding(.horizontal, 6)
        }
        .padding(.bottom, 4)
    }

    private var timerLabel: String {
        let m = coordinator.timerRemaining / 60
        let s = coordinator.timerRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

        // MARK: Confirmation

    private var confirmationView: some View {
        let metrics = coordinator.metrics
        return VStack(spacing: 8) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    CompanionFaceView(state: .happy, accent: accent, size: 26)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if metrics.hasNotch {
                    Color.clear.frame(width: metrics.notchWidth + 12, height: 1)
                }

                HStack(spacing: 6) {
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: metrics.hasNotch ? max(metrics.topInset - 6, 26) : 28)
            .padding(.horizontal, 4)

            Text(coordinator.confirmationText)
                .font(.perchRounded(13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 6)
        }
        .padding(.bottom, 4)
    }
}
