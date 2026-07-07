import SwiftUI


struct WeeklySummaryView: View {
    @Environment(AppContainer.self) private var container

    private var accent: [Color] { container.personality.activePersonality.accentColors }
    private var summary: WeekSummary { container.memory.weekSummary() }

    var body: some View {
        let week = summary
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                CompanionFaceView(state: .idle, accent: accent, size: 30)
                Text("Your week")
                    .font(.perchRounded(20, weight: .bold))
                Spacer()
            }
            insightCard(week)
            chart(week)
            statsGrid(week)
            Spacer()
        }
        .padding(22)
        .frame(width: 460 * PerchStyle.scale, height: 520 * PerchStyle.scale)
    }

    private func insightCard(_ week: WeekSummary) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "lightbulb.fill")
                .foregroundStyle(accent[0])
            Text(week.insight)
                .font(.perchRounded(12.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func chart(_ week: WeekSummary) -> some View {
        let maxSeconds = max(week.days.map(\.activeSeconds).max() ?? 1, 1)
        return VStack(alignment: .leading, spacing: 8) {
            Text("FOCUS PER DAY")
                .font(.system(size: 9, weight: .semibold, design: .rounded))
                .tracking(1.2)
                .foregroundStyle(.secondary)
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(week.days) { day in
                    VStack(spacing: 5) {
                        Capsule()
                            .fill(PerchStyle.accentGradient(accent))
                            .frame(height: barHeight(day.activeSeconds, maxSeconds: maxSeconds))
                        Text(weekdayLetter(forDayKey: day.date))
                            .font(.system(size: 9, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 140, alignment: .bottom)
        }
        .padding(14)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func barHeight(_ seconds: Double, maxSeconds: Double) -> CGFloat {
        let ratio = seconds / maxSeconds
        return max(CGFloat(ratio) * 110, 3)
    }

    private func statsGrid(_ week: WeekSummary) -> some View {
        Grid(horizontalSpacing: 10, verticalSpacing: 10) {
            GridRow {
                statTile("Total focus", value: shortDuration(seconds: week.totalActiveSeconds), symbol: "flame.fill")
                statTile("Real breaks", value: "\(week.totalBreaks)", symbol: "figure.walk")
            }
            GridRow {
                statTile("Water logged", value: "\(week.totalWater)", symbol: "drop.fill")
                statTile("Overwork days", value: "\(week.overworkDays)", symbol: "hourglass")
            }
        }
    }

    private func statTile(_ label: String, value: String, symbol: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(accent[0])
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.perchRounded(16, weight: .bold))
                    .monospacedDigit()
                Text(label)
                    .font(.perchRounded(10))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(12)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}
