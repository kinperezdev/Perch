import SwiftUI

struct Achievement: Identifiable {
    let id: String
    let title: String
    let description: String
    let icon: String
    let color: Color
    let isUnlocked: Bool
}

struct AchievementsView: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    private var accent: [Color] { container.prefs.activePersonality.accentColors }

    private var achievements: [Achievement] {
        let snap = container.memory.snapshot

        let totalWater = snap.days.reduce(0) { $0 + $1.waterCount }
        let totalAccepted = snap.days.reduce(0) { $0 + $1.checkInsAccepted }
        let totalActiveHours = snap.days.reduce(0.0) { $0 + $1.activeSeconds } / 3600.0
        let maxBreaksInDay = snap.days.map { $0.breaksTaken }.max() ?? 0

        let acceptedSleep = snap.stats.keys.contains { $0.hasPrefix("sleep_") && snap.stats[$0]?.accepted ?? 0 > 0 }

        return [
            Achievement(
                id: "first_step",
                title: "First Step",
                description: "Accept your very first Perch check-in.",
                icon: "sparkles",
                color: .yellow,
                isUnlocked: totalAccepted >= 1
            ),
            Achievement(
                id: "hydro_homie",
                title: "Hydro Homie",
                description: "Log water 10 times in total.",
                icon: "drop.fill",
                color: .cyan,
                isUnlocked: totalWater >= 10
            ),
            Achievement(
                id: "stretch_master",
                title: "Stretch Master",
                description: "Take 5 breaks in a single day.",
                icon: "figure.mind.and.body",
                color: .orange,
                isUnlocked: maxBreaksInDay >= 5
            ),
            Achievement(
                id: "deep_flow",
                title: "Deep Flow",
                description: "Log over 10 hours of focused building.",
                icon: "flame.fill",
                color: .red,
                isUnlocked: totalActiveHours >= 10
            ),
            Achievement(
                id: "good_night",
                title: "Good Night",
                description: "Listen to Perch and actually go to sleep.",
                icon: "moon.zzz.fill",
                color: .indigo,
                isUnlocked: acceptedSleep
            ),
            Achievement(
                id: "balanced_builder",
                title: "Balanced Builder",
                description: "Accept 50 check-ins. You are taking care of yourself!",
                icon: "heart.fill",
                color: .pink,
                isUnlocked: totalAccepted >= 50
            )
        ]
    }

    var body: some View {
        let list = achievements
        ZStack {
            LinearGradient(
                colors: [Color(hex: 0x0B0B0E), Color(hex: 0x121216)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                header(list)

                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        ForEach(list) { achievement in
                            achievementCard(achievement)
                        }
                    }
                    .padding(24)
                }
            }
        }
        .frame(width: 500, height: 440)
        .preferredColorScheme(.dark)
    }

    private func header(_ list: [Achievement]) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Achievements")
                    .font(.perchRounded(22, weight: .bold))
                Text("\(list.filter(\.isUnlocked).count) of \(list.count) unlocked")
                    .font(.perchRounded(13))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 40)
        .padding(.horizontal, 24)
    }

    private func achievementCard(_ ach: Achievement) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(ach.isUnlocked ? ach.color.opacity(0.15) : .white.opacity(0.05))
                    .frame(width: 44, height: 44)
                Image(systemName: ach.isUnlocked ? ach.icon : "lock.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(ach.isUnlocked ? ach.color : .white.opacity(0.2))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(ach.title)
                    .font(.perchRounded(14, weight: .bold))
                    .foregroundStyle(ach.isUnlocked ? .white : .white.opacity(0.4))
                Text(ach.description)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(ach.isUnlocked ? ach.color.opacity(0.4) : .clear, lineWidth: 1)
        )
        .opacity(ach.isUnlocked ? 1.0 : 0.6)
    }
}
