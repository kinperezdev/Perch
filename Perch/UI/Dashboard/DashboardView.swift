import SwiftUI

/// The home window: today at a glance, the week, quick care actions,
struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.openSettings) private var openSettings

    private var accent: [Color] { container.prefs.personality.accentColors }

    /// A warm time-of-day mood for the header. Never sad on the dashboard.
    private var contextualFaceState: CompanionFaceView.FaceState {
        if container.memory.today().checkInsAccepted > 0 { return .happy }
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return .excited
        case 21..<24, 0..<5: return .sleepy
        default: return .happy
        }
    }

    var body: some View {
        ZStack {
            background
            VStack(alignment: .leading, spacing: 16) {
                header
                statsRow
                HStack(alignment: .top, spacing: 12) {
                    weekSection
                    Spacer(minLength: 0)
                    actionsSection
                }
                Spacer(minLength: 0)
                footer
            }
            .padding(26)
        }
        .frame(width: 720 * PerchStyle.scale, height: 380 * PerchStyle.scale)
        .preferredColorScheme(.dark)
    }

    private var background: some View {
        ZStack(alignment: .top) {
            LinearGradient(
                colors: [Color(hex: 0x0B0B0E), Color(hex: 0x121216)],
                startPoint: .top,
                endPoint: .bottom
            )
            Rectangle()
                .fill(.white.opacity(0.06))
                .frame(height: 1)
        }
        .ignoresSafeArea()
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 14) {
            CompanionFaceView(state: contextualFaceState, accent: accent, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(greeting)
                    .font(.perchRounded(23, weight: .heavy))
                HStack(spacing: 6) {
                    Text("\(container.personality.activePersonality.displayName) mode")
                        .font(.perchRounded(11))
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("\(container.subscriptions.currentPlanName) plan")
                        .font(.perchRounded(11))
                        .foregroundStyle(.secondary)
                    if container.prefs.demoMode {
                        Text("DEMO 60x")
                            .font(.system(size: 8, weight: .bold, design: .rounded))
                            .foregroundStyle(.orange)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1.5)
                            .background(.orange.opacity(0.15), in: Capsule())
                    }
                }
            }
            Spacer()

            Button {
                WindowPresenter.shared.showSettings(container)
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Image(systemName: "gearshape.fill")
            }
            .buttonStyle(.glass)
            if container.subscriptions.tier != .premium {
                Button("Upgrade") { WindowPresenter.shared.showPaywall(container) }
                    .buttonStyle(.glassProminent)
                    .tint(accent[0])
            }
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        let daypartWord = hour < 12 ? "morning" : (hour < 18 ? "afternoon" : "evening")
        let call = container.personality.activePersonality.callName(userName: container.prefs.userName)
        return "Good \(daypartWord), \(call)"
    }

    // MARK: Stats

    private var statsRow: some View {
        let today = container.memory.today()
        return HStack(spacing: 10) {
            statTile("Current focus", value: shortDuration(seconds: container.tracker.focusRunSeconds), symbol: "flame.fill")
            statTile("Active today", value: shortDuration(seconds: today.activeSeconds), symbol: "sum")
            statTile("Water", value: "\(today.waterCount)", symbol: "drop.fill")
            statTile("Breaks", value: "\(today.breaksTaken)", symbol: "figure.walk")
        }
    }

    private func statTile(_ label: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 13))
                .foregroundStyle(accent[0])
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.perchRounded(16, weight: .bold))
                    .monospacedDigit()
                Text(label)
                    .font(.perchRounded(9.5))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: Week

    private var weekSection: some View {
        let week = container.memory.weekSummary()
        return VStack(alignment: .leading, spacing: 10) {
            sectionKicker("This week")
            if container.subscriptions.gate.weeklySummary {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(week.days) { day in
                        dayBar(day, maxSeconds: max(week.days.map(\.activeSeconds).max() ?? 1, 1))
                    }
                }
                .frame(height: 130 * PerchStyle.scale, alignment: .bottom)
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "lightbulb.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(accent[0])
                    Text(week.insight)
                        .font(.perchRounded(11.5))
                        .foregroundStyle(.white.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                    Text("Weekly patterns and learned insights unlock with Pro.")
                        .font(.perchRounded(11.5))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("See plans") { WindowPresenter.shared.showPaywall(container) }
                        .buttonStyle(.glass)
                }
                .padding(.vertical, 18)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func dayBar(_ day: HabitMemoryStore.DayLog, maxSeconds: Double) -> some View {
        let ratio = day.activeSeconds / maxSeconds
        return VStack(spacing: 4) {
            Capsule()
                .fill(PerchStyle.accentGradient(accent))
                .frame(height: max(CGFloat(ratio) * 104, 3))
            Text(Self.dayLetter(day.date))
                .font(.system(size: 8.5, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionKicker("Quick actions")
            VStack(spacing: 6) {
                actionButton("Check on me", symbol: "sparkles") {
                    Task { await container.engine.forceCheckIn() }
                }
                actionButton("Talk", symbol: "bubble.left.and.bubble.right.fill") {
                    container.coordinator.openChat()
                }
                actionButton("Log water", symbol: "drop.fill") {
                    container.memory.logWater()
                }
                actionButton("Took a break", symbol: "figure.walk") {
                    container.tracker.creditBreak()
                }
                if container.prefs.isPaused() {
                    actionButton("Resume", symbol: "play.fill") {
                        container.prefs.pausedUntil = nil
                    }
                } else {
                    actionButton("Pause 1h", symbol: "pause.fill") {
                        container.prefs.pausedUntil = Date().addingTimeInterval(3600)
                    }
                }
            }
        }
        .frame(width: 148 * PerchStyle.scale)
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.perchRounded(11, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 5)
        }
        .buttonStyle(.glass)
    }

    // MARK: Footer

    private var footer: some View {
        HStack {
            Label(
                "Quick answer: \(QuickAnswerShortcutManager.describe(keyCode: container.prefs.shortcutKeyCode, modifiers: container.prefs.shortcutModifiers))",
                systemImage: "keyboard"
            )
            .font(.perchRounded(10.5))
            .foregroundStyle(.secondary)
            Spacer()
            Text("Everything stays on this Mac.")
                .font(.perchRounded(10.5))
                .foregroundStyle(.tertiary)
        }
    }

    private func sectionKicker(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .tracking(2)
            .foregroundStyle(accent[0].opacity(0.9))
    }

    private static func dayLetter(_ dateKey: String) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let date = formatter.date(from: dateKey) else { return "?" }
        let weekday = Calendar.current.component(.weekday, from: date)
        return ["S", "M", "T", "W", "T", "F", "S"][weekday - 1]
    }
}
