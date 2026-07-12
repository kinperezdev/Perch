import SwiftUI

struct PerchPaywallView: View {
    @Environment(AppContainer.self) private var container
    let onClose: () -> Void

    @State private var selectedID: String?
    @State private var isLoadingOfferings = true

    private var accent: [Color] { container.personality.activePersonality.accentColors }
    private var options: [SubscriptionManager.PlanOption] { container.subscriptions.planOptions }

    var body: some View {
        ZStack {
            background
            VStack(spacing: 14) {
                CompanionFaceView(state: .happy, accent: accent, size: 44)
                VStack(spacing: 4) {
                    Text("Perch Pro")
                        .font(.system(size: 28, weight: .heavy, design: .rounded))
                    Text("Protect the builder while they build.")
                        .font(.perchRounded(12))
                        .foregroundStyle(.secondary)
                }
                featureList
                    .padding(.vertical, 4)
                if isLoadingOfferings {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxHeight: .infinity)
                } else if options.isEmpty {
                    VStack(spacing: 10) {
                        Text(container.subscriptions.lastError ?? "Couldn't load plans.")
                            .font(.perchRounded(11.5))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try again") { Task { await loadOfferings() } }
                            .buttonStyle(.glass)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    VStack(spacing: 8) {
                        ForEach(options) { option in
                            optionRow(option)
                        }
                    }
                }
                purchaseButton
                footer
            }
            .padding(24)
        }
        .frame(width: 440 * PerchStyle.scale, height: 640 * PerchStyle.scale)
        .preferredColorScheme(.dark)
        .task { await loadOfferings() }
    }

    private func loadOfferings() async {
        isLoadingOfferings = true
        await container.subscriptions.loadOfferings()
        isLoadingOfferings = false
        if selectedID == nil {
            selectedID = options.first { $0.periodLabel == "Yearly" }?.id ?? options.first?.id
        }
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

    private var featureList: some View {
        VStack(alignment: .leading, spacing: 6) {
            featureRow("Memory that adapts timing to your habits")
            featureRow("All six personalities, plus a custom companion")
            featureRow("Personalized AI companion check-ins")
            featureRow("Calendar and meeting awareness")
            featureRow("Weekly wellbeing summary and insights")
            featureRow("More personal routines")
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(accent[0])
            Text(text)
                .font(.perchRounded(11.5))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func optionRow(_ option: SubscriptionManager.PlanOption) -> some View {
        let isSelected = selectedID == option.id
        return Button {
            selectedID = option.id
        } label: {
            HStack(spacing: 10) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 15))
                    .foregroundStyle(isSelected ? accent[0] : .white.opacity(0.3))
                VStack(alignment: .leading, spacing: 1) {
                    Text(option.periodLabel)
                        .font(.perchRounded(13.5, weight: .semibold))
                    if let introText = option.introText {
                        Text(introText)
                            .font(.perchRounded(9.5, weight: .medium))
                            .foregroundStyle(accent[0])
                    }
                }
                if let note = option.note {
                    Text(note)
                        .font(.system(size: 9, weight: .bold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(PerchStyle.accentGradient(accent), in: Capsule())
                }
                Spacer()
                Text(option.priceLabel)
                    .font(.perchRounded(14, weight: .bold))
                    .monospacedDigit()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(accent[0].opacity(0.13)) : AnyShapeStyle(.white.opacity(0.05)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(isSelected ? accent[0].opacity(0.55) : .white.opacity(0.07), lineWidth: 1.2)
            )
        }
        .buttonStyle(.plain)
    }

    private var purchaseButton: some View {
        Button {
            guard let option = options.first(where: { $0.id == selectedID }) else { return }
            Task {
                await container.subscriptions.purchase(option)
                if container.subscriptions.tier != .free {
                    try? await Task.sleep(nanoseconds: 400_000_000)
                    onClose()
                }
            }
        } label: {
            HStack(spacing: 8) {
                if container.subscriptions.isWorking {
                    ProgressView().controlSize(.small)
                }
                Text("Unlock Perch Pro")
                    .frame(maxWidth: .infinity)
            }
        }
        .buttonStyle(BigActionButtonStyle(accent: accent))
        .disabled(selectedID == nil || container.subscriptions.isWorking || options.isEmpty)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack {
                Button("Restore purchases") {
                    Task { await container.subscriptions.restorePurchases() }
                }
                .buttonStyle(.plain)
                .font(.perchRounded(11))
                .foregroundStyle(.secondary)
                Spacer()
                Button("Maybe later") { onClose() }
                    .buttonStyle(.plain)
                    .font(.perchRounded(11))
                    .foregroundStyle(.secondary)
            }
            if container.subscriptions.mode == .demo {
                Text("Demo mode: purchases are simulated locally.")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.orange)
            }
            if let error = container.subscriptions.lastError {
                Text(error)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(.orange)
                    .lineLimit(2)
            }
        }
    }
}
