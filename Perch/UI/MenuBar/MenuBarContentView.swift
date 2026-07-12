import SwiftUI

/// The status item popover: session at a glance, quick care actions,
struct MenuBarContentView: View {
    @Environment(AppContainer.self) private var container

    private var accent: [Color] { container.prefs.personality.accentColors }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header
            statsCard
            if let hint = container.engine.nextHint() {
                Label(hint, systemImage: "clock")
                    .font(.perchRounded(10.5))
                    .foregroundStyle(.secondary)
            }
            quickActions
            pauseRow
            Divider()
            footer
        }
        .padding(14)
        .frame(width: 330)
    }

    private var header: some View {
        HStack(spacing: 10) {
            CompanionFaceView(state: .idle, accent: accent, size: 30)
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 6) {
                    Text(container.personality.companionName)
                        .font(.perchRounded(15, weight: .bold))
                    if container.subscriptions.tier != .free {
                        ProTag(text: container.subscriptions.currentPlanName.uppercased())
                    }
                }
                Text(container.personality.activePersonality.displayName + " mode")
                    .font(.perchRounded(10.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if container.prefs.demoMode {
                Text("DEMO 60x")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.orange.opacity(0.15), in: Capsule())
            }
        }
    }

    private var statsCard: some View {
        let today = container.memory.today()
        return VStack(spacing: 7) {
            StatRow(
                symbol: "flame.fill",
                label: "Current focus",
                value: shortDuration(seconds: container.tracker.focusRunSeconds)
            )
            StatRow(
                symbol: "sum",
                label: "Active today",
                value: shortDuration(seconds: today.activeSeconds)
            )
            StatRow(symbol: "drop.fill", label: "Water logged", value: "\(today.waterCount)")
            StatRow(symbol: "figure.walk", label: "Breaks taken", value: "\(today.breaksTaken)")
        }
        .padding(11)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: PerchStyle.cardRadius, style: .continuous))
    }

    private var quickActions: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                actionButton("Check on me", symbol: "sparkles") {
                    Task { await container.engine.forceCheckIn() }
                }
                actionButton("Talk", symbol: "bubble.left.and.bubble.right.fill") {
                    container.coordinator.openChat()
                }
            }
            HStack(spacing: 8) {
                actionButton("Log water", symbol: "drop.fill") {
                    container.memory.logWater()
                }
                actionButton("I took a break", symbol: "figure.walk") {
                    container.tracker.creditBreak()
                }
            }
        }
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
                .font(.perchRounded(11.5, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
    }

    private var pauseRow: some View {
        HStack {
            if container.prefs.isPaused() {
                Label("Paused", systemImage: "pause.fill")
                    .font(.perchRounded(11))
                    .foregroundStyle(.orange)
                Spacer()
                Button("Resume") { container.prefs.pausedUntil = nil }
                    .buttonStyle(.glass)
                    .font(.perchRounded(11))
            } else {
                Label("Check ins active", systemImage: "checkmark.circle.fill")
                    .font(.perchRounded(11))
                    .foregroundStyle(.green.opacity(0.8))
                Spacer()
                Menu("Pause") {
                    Button("For 1 hour") {
                        container.prefs.pausedUntil = Date().addingTimeInterval(3600)
                    }
                    Button("Until tomorrow") {
                        container.prefs.pausedUntil = Calendar.current.startOfDay(
                            for: Date().addingTimeInterval(86400)
                        )
                    }
                }
                .menuStyle(.borderlessButton)
                .font(.perchRounded(11))
                .frame(width: 76)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                Button {
                    WindowPresenter.shared.showDashboard(container)
                } label: {
                    Label("Dashboard", systemImage: "rectangle.grid.2x2.fill")
                        .font(.perchRounded(11.5))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.primary)
                Spacer()
                Text(QuickAnswerShortcutManager.describe(
                    keyCode: container.prefs.shortcutKeyCode,
                    modifiers: container.prefs.shortcutModifiers
                ))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(.tertiary)
            }
            HStack {
                Button("Settings") {
                    WindowPresenter.shared.showSettings(container)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.plain)
                .font(.perchRounded(11.5))
                Spacer()
                if container.subscriptions.tier != .premium {
                    Button("Upgrade") { WindowPresenter.shared.showPaywall(container) }
                        .buttonStyle(.glassProminent)
                        .font(.perchRounded(11, weight: .semibold))
                }
                Button("Quit") { NSApp.terminate(nil) }
                    .buttonStyle(.plain)
                    .font(.perchRounded(11.5))
                    .foregroundStyle(.secondary)
            }
        }
    }
}
