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
                    if container.subscriptions.tier != .pro {
                        Button("Upgrade") { WindowPresenter.shared.showPaywall(container) }
                            .buttonStyle(.borderedProminent)
                    }
                }
            }
            Section {
                Button("Restore purchases") {
                    Task { await container.subscriptions.restorePurchases() }
                }
                Text("Reinstalled Perch or switched Macs? Restore brings back a plan you already bought.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if container.subscriptions.mode == .demo {
                    Button("Reset demo plan to Free") {
                        container.subscriptions.resetDemoTier()
                    }
                    Text("Demo mode is on. Purchases here aren't real yet.")
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
        case .free: "Smart check ins, two personalities, manual habits"
        case .pro: "Everything unlocked: memory, weekly insights, calendar, all personalities"
        }
    }
}
