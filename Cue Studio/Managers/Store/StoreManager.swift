//
//  StoreManager.swift
//  Cue Studio
//

import StoreKit

/// Cue Pro purchases (StoreKit 2): monthly and annual subscriptions, each with a 7-day free trial.
/// Pro changes one thing, unlimited exports; every feature is open on the free plan too.
///
/// There is no backend, so entitlements rely on StoreKit's own JWS verification (`.verified`).
/// If Cue ever gets a server, purchases must be re-verified there before unlocking anything.
@MainActor
@Observable
final class StoreManager {
    private(set) var products: [ProPlan: Product] = [:]
    private(set) var tier: MembershipTier = .free
    private(set) var activePlan: ProPlan?
    /// Renewal (or expiry) date of the active subscription.
    private(set) var renewalDate: Date?
    private(set) var isLoadingProducts = false
    private(set) var purchasingPlan: ProPlan?
    var errorMessage: String?

    private var updatesTask: Task<Void, Never>?
    private var forcedTier: MembershipTier?
    #if DEBUG
    /// UI tests can't load the StoreKit products: they show the prices of the design (`CueStudio.storekit`) instead, so the paywall can be looked at.
    private let showsSamplePrices = ProcessInfo.processInfo.arguments.contains("-uiTestInMemory")
    #endif

    init() {
        #if DEBUG
        // UI tests start the app already on Pro.
        if ProcessInfo.processInfo.arguments.contains("-uiTestPro") {
            forcedTier = .subscriber
            tier = .subscriber
            activePlan = .annual
        }
        #endif
    }

    /// Loads products, reads current entitlements and starts listening for transaction updates.
    func start() async {
        if updatesTask == nil {
            updatesTask = Task { [weak self] in
                for await update in Transaction.updates {
                    if case .verified(let transaction) = update {
                        await transaction.finish()
                    }
                    await self?.refreshEntitlements()
                }
            }
        }
        await loadProducts()
        await refreshEntitlements()
    }

    // MARK: - Products

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            let loaded = try await Product.products(for: ProPlan.allCases.map(\.productID))
            var byPlan: [ProPlan: Product] = [:]
            for product in loaded {
                if let plan = ProPlan(productID: product.id) { byPlan[plan] = product }
            }
            products = byPlan
        } catch {
            errorMessage = String(localized: "Couldn't reach the App Store. Check your connection and try again.")
        }
    }

    func displayPrice(for plan: ProPlan) -> String? {
        #if DEBUG
        if showsSamplePrices, products[plan] == nil { return plan == .annual ? "$39.99" : "$7.99" }
        #endif
        return products[plan]?.displayPrice
    }

    /// "$3.33" for the annual plan, so it can be compared with monthly.
    func monthlyEquivalentText(for plan: ProPlan) -> String? {
        #if DEBUG
        if showsSamplePrices, products[plan] == nil { return plan == .annual ? "$3.33" : nil }
        #endif
        guard plan == .annual, let product = products[plan] else { return nil }
        return PricingMath.monthlyEquivalent(ofYearly: product.price).formatted(product.priceFormatStyle)
    }

    var annualSavingsPercent: Int? {
        #if DEBUG
        if showsSamplePrices, products.isEmpty { return 58 }
        #endif
        guard let monthly = products[.monthly]?.price, let yearly = products[.annual]?.price else { return nil }
        return PricingMath.savingsPercent(monthlyPrice: monthly, yearlyPrice: yearly)
    }

    /// Length of the free trial in days when the creator is still eligible for it; nil otherwise.
    func freeTrialDays(for plan: ProPlan) async -> Int? {
        #if DEBUG
        if showsSamplePrices, products[plan] == nil { return 7 }
        #endif
        guard let subscription = products[plan]?.subscription,
              let offer = subscription.introductoryOffer,
              offer.paymentMode == .freeTrial,
              await subscription.isEligibleForIntroOffer
        else { return nil }
        let value = offer.period.value * offer.periodCount
        switch offer.period.unit {
        case .day: return value
        case .week: return value * 7
        case .month: return value * 30
        case .year: return value * 365
        @unknown default: return nil
        }
    }

    // MARK: - Purchasing

    /// Returns true when the purchase unlocked Pro.
    func purchase(_ plan: ProPlan) async -> Bool {
        guard let product = products[plan] else {
            errorMessage = String(localized: "Can't reach the App Store")
            return false
        }
        purchasingPlan = plan
        defer { purchasingPlan = nil }
        do {
            switch try await product.purchase() {
            case .success(let result):
                guard case .verified(let transaction) = result else {
                    errorMessage = String(localized: "The App Store couldn't verify this purchase.")
                    return false
                }
                await transaction.finish()
                await refreshEntitlements()
                return tier.isPro
            case .pending:
                errorMessage = String(localized: "Your purchase is waiting for approval.")
                return false
            case .userCancelled:
                return false
            @unknown default:
                return false
            }
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    /// 04 · F7: no internet is "Can't reach the App Store"; anything else is "Purchase didn't go through".
    nonisolated static func message(for error: Error) -> String {
        if let store = error as? StoreKitError, case .networkError = store { return String(localized: "Can't reach the App Store") }
        if let url = error as? URLError, [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotConnectToHost].contains(url.code) {
            return String(localized: "Can't reach the App Store")
        }
        return String(localized: "Purchase didn't go through")
    }

    /// Syncs with the App Store. Returns true when Pro is active afterwards.
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = Self.message(for: error)
        }
        await refreshEntitlements()
        return tier.isPro
    }

    func refreshEntitlements() async {
        if let forcedTier {
            tier = forcedTier
            return
        }
        var newTier = MembershipTier.free
        var plan: ProPlan?
        var renewal: Date?
        for await entitlement in Transaction.currentEntitlements {
            guard case .verified(let transaction) = entitlement,
                  transaction.revocationDate == nil,
                  let owned = ProPlan(productID: transaction.productID)
            else { continue }
            if (transaction.expirationDate ?? .distantFuture) > .now {
                newTier = .subscriber
                plan = owned
                renewal = transaction.expirationDate
            }
        }
        tier = newTier
        activePlan = plan
        renewalDate = renewal
    }
}
