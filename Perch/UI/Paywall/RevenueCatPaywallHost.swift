import RevenueCat
import SwiftUI
#if canImport(RevenueCatUI) && os(iOS)
import RevenueCatUI
#endif

/// Subscription management. RevenueCat Customer Center is iOS only for
struct CustomerCenterHost: View {
    @Environment(AppContainer.self) private var container

    var body: some View {
        #if canImport(RevenueCatUI) && os(iOS)
        RevenueCatUI.CustomerCenterView()
            .frame(minWidth: 480, minHeight: 560)
        #else
        VStack(spacing: 14) {
            Image(systemName: "person.crop.circle.badge.checkmark")
                .font(.system(size: 30))
                .foregroundStyle(.secondary)
            Text("Manage your subscription")
                .font(.perchRounded(16, weight: .semibold))
            Text("Plan changes and cancellations happen through your App Store account. Purchases can be restored here anytime.")
                .font(.perchRounded(11.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 320)
            HStack(spacing: 10) {
                Link("App Store subscriptions", destination: URL(string: "https://apps.apple.com/account/subscriptions")!)
                Button("Restore purchases") {
                    Task { await container.subscriptions.restorePurchases() }
                }
            }
            if let error = container.subscriptions.lastError {
                Text(error).font(.caption).foregroundStyle(.orange)
            }
        }
        .padding(28)
        .frame(width: 440, height: 300)
        #endif
    }
}
