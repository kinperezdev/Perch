import SwiftUI

struct SubscriptionSettingsView: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        Form {
            Section("Current plan") {
                HStack(spacing: 10) {
                    Image(systemName: planSymbol)
                        .foregroundStyle(planColor)
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
                Text("Reinstalled Perchie or switched Macs? Restore brings back a plan you already bought.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if container.subscriptions.mode == .demo {
                    Button("Reset demo plan & trial") {
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

    private var planSymbol: String {
        let subs = container.subscriptions
        if subs.tier == .pro { return "crown.fill" }
        return subs.isLocked ? "lock.fill" : "hourglass"
    }

    private var planColor: Color {
        let subs = container.subscriptions
        if subs.tier == .pro { return .yellow }
        return subs.isLocked ? .red : .green
    }

    private var planBlurb: String {
        let subs = container.subscriptions
        if subs.tier == .pro {
            return "Everything unlocked: memory, weekly insights, calendar, all personalities"
        }
        if subs.isLocked {
            return "Your free trial ended. Unlock Perchie Pro to keep using Perchie."
        }
        return "Full access during your free trial, \(subs.trialDaysRemaining) day\(subs.trialDaysRemaining == 1 ? "" : "s") left"
    }
}
