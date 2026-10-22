//
//  StoreManagerTests.swift
//  Cue StudioTests
//

import Foundation
import StoreKit
import StoreKitTest
import Testing
@testable import Cue_Studio

/// Cue Pro against StoreKit's own test store, with the products of `CueStudio.storekit`: what the creator bought, let lapse or
/// got back is what the tier says. One session at a time (StoreKit's test store is the whole process's).
@MainActor
@Suite("Cue Pro purchases", .serialized, .timeLimit(.minutes(2)))
struct StoreManagerTests {
    /// A clean test store: nothing bought, no dialogs. The configuration is the one the scheme uses (`Fixtures/CueStudio.storekit`,
    /// in this bundle: the Simulator can't read the project's folder).
    private func session() throws -> SKTestSession {
        let url = try #require(Bundle(for: FakeExportCountStore.self).url(forResource: "CueStudio", withExtension: "storekit"))
        let session = try SKTestSession(contentsOf: url)
        session.resetToDefaultState()
        session.clearTransactions()
        session.disableDialogs = true
        return session
    }

    /// The test store settles a clean start on its own time too: what an earlier test bought must be gone before this one buys.
    private func nothingOwned() async {
        for _ in 0..<50 {
            var owned = false
            for await _ in Transaction.currentEntitlements { owned = true }
            if !owned { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// StoreKit's test store settles a purchase, an expiry or a renewal on its own time: `refreshEntitlements` until the tier is
    /// `tier` (at most 5 s), the way the app hears of it through `Transaction.updates`.
    private func refresh(_ store: StoreManager, until tier: MembershipTier) async {
        for _ in 0..<50 {
            await store.refreshEntitlements()
            if store.tier == tier { return }
            try? await Task.sleep(for: .milliseconds(100))
        }
    }

    /// The latest monthly transaction's renewal state, once it is `state` (at most 5 s).
    private func renewalState(becomes state: Product.SubscriptionInfo.RenewalState) async -> Product.SubscriptionInfo.RenewalState? {
        var last: Product.SubscriptionInfo.RenewalState?
        for _ in 0..<50 {
            if case .verified(let transaction)? = await Transaction.latest(for: ProPlan.monthly.productID) {
                last = await transaction.subscriptionStatus?.state
                if last == state { return last }
            }
            try? await Task.sleep(for: .milliseconds(100))
        }
        return last
    }

    @Test func aBoughtPlanIsPro() async throws {
        let session = try session()
        let store = StoreManager()
        await store.refreshEntitlements()
        #expect(store.tier == .free)

        try await session.buyProduct(identifier: ProPlan.annual.productID)
        await refresh(store, until: .subscriber)
        #expect(store.tier == .subscriber)
        #expect(store.activePlan == .annual)
        #expect(store.renewalDate != nil)
    }

    @Test func anExpiredSubscriptionIsFreeAgain() async throws {
        let session = try session()
        await nothingOwned()
        try await session.buyProduct(identifier: ProPlan.monthly.productID)
        try session.expireSubscription(productIdentifier: ProPlan.monthly.productID)
        let store = StoreManager()
        await refresh(store, until: .free)
        #expect(store.tier == .free)
        #expect(store.activePlan == nil)
    }

    @Test func aRefundedSubscriptionIsFreeAgain() async throws {
        let session = try session()
        await nothingOwned()
        let bought = try await session.buyProduct(identifier: ProPlan.annual.productID)
        try session.refundTransaction(identifier: UInt(bought.id))
        let store = StoreManager()
        await refresh(store, until: .free)
        #expect(store.tier == .free)
    }

    /// The renewal's payment failed and Apple retries it: the creator keeps Pro meanwhile.
    @Test func aSubscriptionInTheBillingGracePeriodStaysPro() async throws {
        let session = try session()
        session.billingGracePeriodIsEnabled = true
        session.shouldEnterBillingRetryOnRenewal = true
        try await session.buyProduct(identifier: ProPlan.monthly.productID)
        try session.forceRenewalOfSubscription(productIdentifier: ProPlan.monthly.productID)
        #expect(await renewalState(becomes: .inGracePeriod) == .inGracePeriod, "the test store is in the grace period")
        let store = StoreManager()
        await refresh(store, until: .subscriber)
        #expect(store.tier == .subscriber)
        #expect(store.activePlan == .monthly)
    }
}
