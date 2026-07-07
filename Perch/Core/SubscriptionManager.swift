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


    static let perchProEntitlementID = "Perch Pro"

    private(set) var mode: Mode
    private(set) var tier: PlanTier = .free
    private(set) var planOptions: [PlanOption] = []
    private(set) var isWorking = false
    private(set) var lastError: String?

    var gate: FeatureGate { FeatureGate(tier: tier) }


    var currentPlanName: String {
        if tier == .free { return "Free" }
        return mode == .revenueCat ? "Perch Pro" : tier.displayName
    }

    init() {
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
        if info.entitlements[Self.perchProEntitlementID]?.isActive == true {
            tier = .premium
        } else if info.entitlements["premium"]?.isActive == true {
            tier = .premium
        } else if info.entitlements["pro"]?.isActive == true {
            tier = .pro
        } else {
            tier = .free
        }
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
                        tier: .premium,
                        periodLabel: Self.periodLabel(for: package.packageType),
                        priceLabel: package.storeProduct.localizedPriceString,
                        note: package.packageType == .lifetime ? "Pay once" : nil,
                        introText: Self.introText(for: package.storeProduct),
                        package: package
                    )
                }
                .sorted { Self.sortOrder($0.periodLabel) < Self.sortOrder($1.periodLabel) }
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
            lastError = "Demo mode: nothing to restore."
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
    }

        // MARK: Static helpers

    private static func friendlyMessage(for error: Error) -> String {
        if let code = error as? RevenueCat.ErrorCode {
            switch code {
            case .networkError, .offlineConnectionError:
                return "No connection. Your purchase state will sync when you're back online."
            case .paymentPendingError:
                return "Payment is pending approval. Access unlocks once it clears."
            case .productAlreadyPurchasedError:
                return "Already purchased. Try Restore purchases."
            case .configurationError, .invalidCredentialsError:
                return "Store configuration issue. Check the RevenueCat dashboard setup."
            default:
                return code.localizedDescription
            }
        }
        return error.localizedDescription
    }


    private static func introText(for product: StoreProduct) -> String? {
        guard let intro = product.introductoryDiscount else { return nil }
        let count = intro.subscriptionPeriod.value
        let unit: String
        switch intro.subscriptionPeriod.unit {
        case .day: unit = count == 1 ? "day" : "days"
        case .week: unit = count == 1 ? "week" : "weeks"
        case .month: unit = count == 1 ? "month" : "months"
        case .year: unit = count == 1 ? "year" : "years"
        @unknown default: unit = "days"
        }
        if intro.paymentMode == .freeTrial {
            return "\(count) \(unit) free"
        }
        return "\(intro.localizedPriceString) intro"
    }

    private static func sortOrder(_ periodLabel: String) -> Int {
        switch periodLabel {
        case "Monthly": 0
        case "Yearly": 1
        case "Lifetime": 2
        default: 3
        }
    }

    private static func periodLabel(for type: PackageType) -> String {
        switch type {
        case .monthly: "Monthly"
        case .annual: "Yearly"
        case .weekly: "Weekly"
        case .lifetime: "Lifetime"
        default: "Plan"
        }
    }

    private static let demoPlans: [PlanOption] = [
        PlanOption(id: "monthly", tier: .premium, periodLabel: "Monthly", priceLabel: "$9.99", note: nil, introText: "7 days free", package: nil),
        PlanOption(id: "yearly", tier: .premium, periodLabel: "Yearly", priceLabel: "$79.99", note: "Save 33%", introText: "7 days free", package: nil),
        PlanOption(id: "lifetime", tier: .premium, periodLabel: "Lifetime", priceLabel: "$99.99", note: "Pay once", introText: nil, package: nil),
    ]
}
