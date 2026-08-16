import Foundation
import Observation
import RevenueCat

@MainActor
@Observable
final class SubscriptionManager {

    enum Mode {
        case revenueCat
        case demo
    }

    struct PlanOption: Identifiable {
        let id: String
        let tier: PlanTier
        let periodLabel: String
        let priceLabel: String
        let note: String?

        let introText: String?
        let package: Package?
    }

    private static var resolvedKey: String {
        if let env = ProcessInfo.processInfo.environment["PERCH_REVENUECAT_KEY"], !env.isEmpty {
            return env
        }
        if let fromFile = keyFromSecrets(), !fromFile.isEmpty, !fromFile.hasPrefix("REPLACE") {
            return fromFile
        }
        return ""
    }

    private static func keyFromSecrets() -> String? {
        guard
            let url = Bundle.main.url(forResource: "Secrets", withExtension: "plist"),
            let dict = NSDictionary(contentsOf: url)
        else { return nil }
        return dict["RevenueCatAPIKey"] as? String
    }

    static let perchProEntitlementID = "Perchie Pro"

    /// Length of the free trial, starting from first launch.
    static let trialDurationDays = 3

    private(set) var mode: Mode
    private(set) var tier: PlanTier = .free
    private(set) var planOptions: [PlanOption] = []
    private(set) var isWorking = false
    private(set) var lastError: String?

    /// First-launch date, persisted so the trial window survives relaunches.
    private var installDate: Date

    private var trialEndDate: Date {
        Calendar.current.date(byAdding: .day, value: Self.trialDurationDays, to: installDate) ?? installDate
    }

    var isTrialActive: Bool { Date() < trialEndDate }

    var trialDaysRemaining: Int {
        guard isTrialActive else { return 0 }
        let seconds = trialEndDate.timeIntervalSince(Date())
        return max(1, Int((seconds / 86400).rounded(.up)))
    }

    /// True once the trial has run out and no purchase has unlocked Pro:
    /// the app should stop working entirely, not just hide extra features.
    var isLocked: Bool { tier == .free && !isTrialActive }

    /// The trial grants full Pro-level access while it's running.
    private var effectiveTier: PlanTier { tier == .pro ? .pro : (isTrialActive ? .pro : .free) }

    var gate: FeatureGate { FeatureGate(tier: effectiveTier) }

    var currentPlanName: String {
        if tier == .pro { return mode == .revenueCat ? "Perchie Pro" : tier.displayName }
        if isTrialActive { return "Free trial · \(trialDaysRemaining)d left" }
        return "Trial ended"
    }

    init() {
        if let stored = UserDefaults.standard.object(forKey: "installDate") as? Date {
            installDate = stored
        } else {
            let now = Date()
            UserDefaults.standard.set(now, forKey: "installDate")
            installDate = now
        }

        let key = Self.resolvedKey
        if key.isEmpty || key.hasPrefix("REPLACE") {
            mode = .demo
            tier = PlanTier(rawValue: UserDefaults.standard.string(forKey: "demoTier") ?? "") ?? .free
            planOptions = Self.demoPlans
        } else {
            mode = .revenueCat
            #if DEBUG
            Purchases.logLevel = .debug
            #else
            Purchases.logLevel = .warn
            #endif
            Purchases.configure(withAPIKey: key)
            observeCustomerInfo()
            Task {
                await refreshCustomerInfo()
                await loadOfferings()
            }
        }
    }

        // MARK: Customer info

    private func observeCustomerInfo() {
        Task { [weak self] in
            for await info in Purchases.shared.customerInfoStream {
                await MainActor.run { self?.apply(info) }
            }
        }
    }

    func refreshCustomerInfo() async {
        guard mode == .revenueCat else { return }
        do {
            apply(try await Purchases.shared.customerInfo())
        } catch {
            lastError = Self.friendlyMessage(for: error)
        }
    }

    func refresh(with info: CustomerInfo) {
        apply(info)
    }

    private func apply(_ info: CustomerInfo) {
        tier = info.entitlements[Self.perchProEntitlementID]?.isActive == true ? .pro : .free
    }

        // MARK: Offerings

    func loadOfferings() async {
        guard mode == .revenueCat else { return }
        do {
            let offerings = try await Purchases.shared.offerings()
            guard let current = offerings.current else {
                planOptions = []
                return
            }
            planOptions = current.availablePackages
                .map { package in
                    PlanOption(
                        id: package.identifier,
                        tier: .pro,
                        periodLabel: "One-time",
                        priceLabel: package.storeProduct.localizedPriceString,
                        note: "Pay once, unlock everything",
                        introText: nil,
                        package: package
                    )
                }
        } catch {
            lastError = Self.friendlyMessage(for: error)
        }
    }

        // MARK: Actions

    func purchase(_ option: PlanOption) async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        switch mode {
        case .demo:
            try? await Task.sleep(nanoseconds: 600_000_000)
            tier = option.tier
            UserDefaults.standard.set(option.tier.rawValue, forKey: "demoTier")
        case .revenueCat:
            guard let package = option.package else { return }
            do {
                let result = try await Purchases.shared.purchase(package: package)
                if !result.userCancelled {
                    apply(result.customerInfo)
                }
            } catch let error as RevenueCat.ErrorCode where error == .purchaseCancelledError {
            } catch {
                lastError = Self.friendlyMessage(for: error)
            }
        }
    }

    func restorePurchases() async {
        isWorking = true
        defer { isWorking = false }
        lastError = nil
        switch mode {
        case .demo:
            lastError = "Demo mode is on. There's nothing to restore."
        case .revenueCat:
            do {
                apply(try await Purchases.shared.restorePurchases())
            } catch {
                lastError = Self.friendlyMessage(for: error)
            }
        }
    }

    func resetDemoTier() {
        guard mode == .demo else { return }
        tier = .free
        UserDefaults.standard.set(PlanTier.free.rawValue, forKey: "demoTier")
        let now = Date()
        installDate = now
        UserDefaults.standard.set(now, forKey: "installDate")
    }

        // MARK: Static helpers

    private static func friendlyMessage(for error: Error) -> String {
        if let code = error as? RevenueCat.ErrorCode {
            switch code {
            case .networkError, .offlineConnectionError:
                return "No internet connection. This will update automatically once you're back online."
            case .paymentPendingError:
                return "Payment is pending approval. Access unlocks once it clears."
            case .productAlreadyPurchasedError:
                return "Already purchased. Try Restore purchases."
            case .configurationError, .invalidCredentialsError:
                return "The store isn't set up right now. Try again in a bit."
            default:
                return "Something went wrong with that purchase. Try again."
            }
        }
        return "Something went wrong with that purchase. Try again."
    }

    private static let demoPlans: [PlanOption] = [
        PlanOption(id: "pro_unlock", tier: .pro, periodLabel: "One-time", priceLabel: "$9.99", note: "Pay once, unlock everything", introText: nil, package: nil),
    ]
}
