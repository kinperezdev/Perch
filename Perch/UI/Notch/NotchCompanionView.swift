import SwiftUI


struct NotchCompanionView: View {
    let coordinator: CompanionCoordinator

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
        .background(shape.fill(.black))
        .compositingGroup()
        .shadow(color: .black.opacity(0.45), radius: 16, y: 8)
        .padding(.top, metrics.hasNotch ? 0 : 6)
        .onHover { coordinator.isHovering = $0 }
    }


    private func topPadding(for metrics: NotchMetrics) -> CGFloat {
        guard metrics.hasNotch else { return 10 }
        return (coordinator.phase == .chat || coordinator.phase == .message) ? 4 : metrics.topInset + 3
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
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 0) {
                HStack(spacing: 8) {
                    CompanionFaceView(state: faceState(for: checkIn), accent: accent, size: 26)
                    HStack(spacing: 5) {
                        Image(systemName: checkIn.kind.symbolName)
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(accent[0])
                        Text(checkIn.kind.displayName.uppercased())
                            .font(.system(size: 9, weight: .semibold, design: .rounded))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.45))
                            .lineLimit(1)
                            .fixedSize()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if metrics.hasNotch {
                    Color.clear.frame(width: metrics.notchWidth + 12, height: 1)
                }

                HStack {
                    dismissButton(for: checkIn)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .frame(height: metrics.hasNotch ? max(metrics.topInset - 6, 26) : 28)
            .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 6) {
                Text(checkIn.message)
                    .font(.perchRounded(12.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.94))
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                actions(for: checkIn)
            }
            .padding(.horizontal, 6)
        }
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
    private func actions(for checkIn: CheckIn) -> some View {
        HStack(spacing: 6) {
            switch checkIn.kind {
            case .status:
                logButton("Water", symbol: "drop.fill") { coordinator.logWaterQuick() }
                logButton("Meal", symbol: "fork.knife") { coordinator.logMealQuick() }
                logButton("Break", symbol: "figure.walk") { coordinator.takeBreakQuick() }
                logButton("Shower", symbol: "shower.fill") { coordinator.logShowerQuick() }
                Spacer()
                Button(action: { coordinator.respond(.done) }) { Text("All good") }
                    .buttonStyle(PillButtonStyle(accent: accent))
                    .keyboardShortcut("1", modifiers: [])
            case .welcome, .sessionStart:
                Button(action: { coordinator.respond(.snoozed(minutes: 10)) }) { Text("In a bit") }
                    .buttonStyle(GhostPillButtonStyle())
                    .keyboardShortcut("2", modifiers: [])
                Button(action: { coordinator.respond(.ignored) }) { Text("Just chilling") }
                    .buttonStyle(GhostPillButtonStyle())
                    .keyboardShortcut("3", modifiers: [])
                Spacer()
                Button(action: { coordinator.respond(.done) }) { Text("Let's go") }
                    .buttonStyle(PillButtonStyle(accent: accent))
                    .keyboardShortcut("1", modifiers: [])
            default:
                Button {
                    coordinator.respond(.done)
                } label: {
                    HStack(spacing: 4) {
                        keycap("1", dark: true)
                        Text(checkIn.kind.primaryActionLabel)
                    }
                }
                .buttonStyle(PillButtonStyle(accent: accent))
                .keyboardShortcut("1", modifiers: [])
                if checkIn.kind.supportsTimer {
                    Button {
                        coordinator.startTimer()
                    } label: {
                        HStack(spacing: 4) {
                            keycap("2", dark: false)
                            Text("Timer")
                        }
                    }
                    .buttonStyle(GhostPillButtonStyle())
                    .keyboardShortcut("2", modifiers: [])
                }
                Button {
                    coordinator.respond(.snoozed(minutes: 10))
                } label: {
                    HStack(spacing: 4) {
                        keycap("3", dark: false)
                        Text("Later")
                    }
                }
                .buttonStyle(GhostPillButtonStyle())
                .keyboardShortcut("3", modifiers: [])
                Spacer()
            }
        }
    }


    private func logButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 9, weight: .semibold))
                Text(title)
            }
        }
        .buttonStyle(GhostPillButtonStyle())
        .help("Log \(title.lowercased())")
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
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(.white.opacity(0.12), lineWidth: 4)
                Circle()
                    .trim(from: 0, to: CGFloat(coordinator.timerRemaining) / CGFloat(max(coordinator.timerTotal, 1)))
                    .stroke(
                        LinearGradient(colors: accent, startPoint: .top, endPoint: .bottom),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: coordinator.timerRemaining)
                Text(timerLabel)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.white)
            }
            .frame(width: 46, height: 46)
            VStack(alignment: .leading, spacing: 3) {
                Text("Reset in progress")
                    .font(.perchRounded(13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.92))
                Text("Move a little. I'll keep count.")
                    .font(.perchRounded(11))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Spacer()
            Button("Finish") { coordinator.finishTimer(completed: false) }
                .buttonStyle(GhostPillButtonStyle())
        }
        .padding(.vertical, 8)
    }

    private var timerLabel: String {
        let m = coordinator.timerRemaining / 60
        let s = coordinator.timerRemaining % 60
        return String(format: "%d:%02d", m, s)
    }

        // MARK: Confirmation

    private var confirmationView: some View {
        HStack(spacing: 10) {
            CompanionFaceView(state: .happy, accent: accent, size: 26)
            Text(coordinator.confirmationText)
                .font(.perchRounded(13, weight: .medium))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(2)
            Spacer()
        }
        .padding(.vertical, 6)
    }
}
