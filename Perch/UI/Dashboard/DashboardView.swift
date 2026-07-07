import SwiftUI


struct DashboardView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.openSettings) private var openSettings
    @State private var showingAchievements = false

    private var accent: [Color] { container.prefs.activePersonality.accentColors }


    private var contextualFaceState: CompanionFaceView.FaceState {
        if container.memory.today().checkInsAccepted > 0 { return .happy }
        switch Calendar.current.component(.hour, from: Date()) {
        case 5..<12: return .excited
        case 21..<24, 0..<5: return .sleepy
        default: return .happy
        }
    }

    var body: some View {
        ZStack(alignment: .top) {
            background
            VStack(alignment: .leading, spacing: 18) {
                header
                statsRow
                HStack(alignment: .top, spacing: 12) {
                    weekSection
                    actionsSection
                }
                footer
            }
            .padding(.horizontal, 30)
            .padding(.bottom, 24)
            .padding(.top, 8)
        }
        .frame(width: 720 * PerchStyle.scale, height: 580 * PerchStyle.scale)
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
                showingAchievements = true
            } label: {
                Image(systemName: "medal.fill")
            }
            .buttonStyle(.glass)

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
        .sheet(isPresented: $showingAchievements) {
            AchievementsView()
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
        return VStack(spacing: 10) {
            HStack(spacing: 10) {
                statTile("Focus", value: shortDuration(seconds: container.tracker.focusRunSeconds), symbol: "flame.fill")
                statTile("Active", value: shortDuration(seconds: today.activeSeconds), symbol: "sum")
                statTile("Water", value: "\(today.waterCount)", symbol: "drop.fill")
            }
            HStack(spacing: 10) {
                statTile("Meals", value: "\(today.mealsLogged)/3", symbol: "fork.knife")
                statTile("Breaks", value: "\(today.breaksTaken)", symbol: "figure.walk")
                statTile("Shower", value: today.showerLogged ? "Done" : "Not yet", symbol: "shower.fill")
            }
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
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(label)
                    .font(.perchRounded(9.5))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

        // MARK: Week

    private var weekSection: some View {
        let week = container.memory.weekSummary()
        let maxSeconds = max(week.days.map(\.activeSeconds).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 10) {
            sectionKicker("This week")
            if container.subscriptions.gate.weeklySummary {
                HStack(alignment: .bottom, spacing: 10) {
                    ForEach(week.days) { day in
                        dayBar(day, maxSeconds: maxSeconds)
                    }
                }
                .frame(height: 160 * PerchStyle.scale, alignment: .bottom)
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
                .frame(height: max(CGFloat(ratio) * 128, 3))
            Text(weekdayLetter(forDayKey: day.date))
                .font(.system(size: 8.5, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

        // MARK: Actions

    private var actionsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionKicker("Quick actions")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                actionButton("Talk", symbol: "bubble.left.and.bubble.right.fill") {
                    container.coordinator.openChat()
                }
                actionButton("Log water", symbol: "drop.fill") {
                    container.memory.logWater()
                }
                actionButton("Log a meal", symbol: "fork.knife") {
                    container.memory.logMeal()
                }
                actionButton("Took a break", symbol: "figure.walk") {
                    container.tracker.creditBreak()
                }
                actionButton("Took a shower", symbol: "shower.fill") {
                    container.memory.logShower()
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
        .frame(width: 230 * PerchStyle.scale)
    }

    private func actionButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: symbol)
                    .font(.system(size: 14))
                Text(title)
                    .font(.perchRounded(9.5, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
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
}
