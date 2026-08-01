import SwiftUI

struct PerchPaywallView: View {
    @Environment(AppContainer.self) private var container
    let onClose: () -> Void

    @State private var isLoadingOfferings = true

    private var accent: [Color] { container.personality.activePersonality.accentColors }
    private var option: SubscriptionManager.PlanOption? { container.subscriptions.planOptions.first }

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
                Spacer(minLength: 0)
                if isLoadingOfferings {
                    ProgressView()
                        .controlSize(.small)
                } else if let option {
                    priceCard(option)
                } else {
                    VStack(spacing: 10) {
                        Text(container.subscriptions.lastError ?? "Couldn't load the plan.")
                            .font(.perchRounded(11.5))
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                        Button("Try again") { Task { await loadOfferings() } }
                            .buttonStyle(.glass)
                    }
                }
                purchaseButton
                footer
            }
            .padding(24)
        }
        .frame(width: 440 * PerchStyle.scale, height: 560 * PerchStyle.scale)
        .preferredColorScheme(.dark)
        .task { await loadOfferings() }
    }

    private func loadOfferings() async {
        isLoadingOfferings = true
        await container.subscriptions.loadOfferings()
        isLoadingOfferings = false
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
            featureRow("All six personalities")
            featureRow("Calendar and meeting awareness")
            featureRow("Weekly wellbeing summary and insights")
            featureRow("Voice check ins, in your own voice or a style")
            featureRow("Up to 20 personal routines")
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

    private func priceCard(_ option: SubscriptionManager.PlanOption) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text("One-time purchase")
                    .font(.perchRounded(13.5, weight: .semibold))
                Text("Pay once, unlock everything, forever.")
                    .font(.perchRounded(9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(option.priceLabel)
                .font(.perchRounded(20, weight: .heavy))
                .monospacedDigit()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(accent[0].opacity(0.13))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(accent[0].opacity(0.55), lineWidth: 1.2)
        )
    }

    private var purchaseButton: some View {
        Button {
            guard let option else { return }
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
        .disabled(option == nil || container.subscriptions.isWorking)
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
