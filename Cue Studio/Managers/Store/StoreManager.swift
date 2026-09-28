//
//  StoreManager.swift
//  Cue Studio
//

import StoreKit

/// Cue Pro purchases (StoreKit 2).
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
        products[plan]?.displayPrice
    }

    func price(for plan: ProPlan) -> Decimal? {
        products[plan]?.price
    }

    /// "$3.33" for the annual plan, so it can be compared with monthly.
    func monthlyEquivalentText(for plan: ProPlan) -> String? {
        guard plan == .annual, let product = products[plan] else { return nil }
        return PricingMath.monthlyEquivalent(ofYearly: product.price).formatted(product.priceFormatStyle)
    }

    var annualSavingsPercent: Int? {
        guard let monthly = products[.monthly]?.price, let yearly = products[.annual]?.price else { return nil }
        return PricingMath.savingsPercent(monthlyPrice: monthly, yearlyPrice: yearly)
    }

    /// Length of the free trial in days when the creator is still eligible for it; nil otherwise.
    func freeTrialDays(for plan: ProPlan) async -> Int? {
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
            errorMessage = String(localized: "This plan isn't available right now.")
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
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// Syncs with the App Store. Returns true when Pro is active afterwards.
    func restore() async -> Bool {
        do {
            try await AppStore.sync()
        } catch {
            errorMessage = error.localizedDescription
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
            if owned == .lifetime {
                // A subscription wins over lifetime so the Profile shows its renewal.
                if newTier == .free { newTier = .lifetime; plan = .lifetime }
            } else if (transaction.expirationDate ?? .distantFuture) > .now {
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
