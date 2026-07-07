import SwiftUI

struct SubscriptionSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Form {
            Section("Current plan") {
                HStack(spacing: 10) {
                    Image(systemName: container.subscriptions.tier == .free ? "leaf" : "crown.fill")
                        .foregroundStyle(container.subscriptions.tier == .free ? .green : .yellow)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(container.subscriptions.currentPlanName)
                            .font(.perchRounded(14, weight: .semibold))
                        Text(planBlurb)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    if container.subscriptions.tier != .premium {
                        Button("Upgrade") { WindowPresenter.shared.showPaywall(container) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            Section {
                if container.subscriptions.mode == .revenueCat, container.subscriptions.tier != .free {
                    Button("Manage subscription") {
                        WindowPresenter.shared.showCustomerCenter(container)
                    }
                }
                Button("Restore purchases") {
                    Task { await container.subscriptions.restorePurchases() }
                }
                if container.subscriptions.mode == .demo {
                    Button("Reset demo plan to Free") {
                        container.subscriptions.resetDemoTier()
                    }
                    Text("Running in demo mode: no RevenueCat key configured. Purchases are simulated locally.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                if let error = container.subscriptions.lastError {
                    Text(error).font(.caption).foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .task {
            await container.subscriptions.refreshCustomerInfo()
            await container.subscriptions.loadOfferings()
        }
    }

    private var planBlurb: String {
        switch container.subscriptions.tier {
        case .free: "Smart check ins and AI chat, two personalities, manual habits"
        case .pro: "Adaptive memory, all personalities, AI chat, calendar"
        case .premium: "Everything unlocked: memory, weekly insights, calendar, custom companion"
        }
    }
}
