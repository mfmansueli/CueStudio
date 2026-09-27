//
//  PaywallCopyTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("PaywallCopy")
struct PaywallCopyTests {
    @Test func trialChangesTheAnnualCallToAction() {
        #expect(PaywallCopy.callToAction(for: .annual, displayPrice: "$39.99", trialDays: 7) == "Start 7-day free trial")
        #expect(PaywallCopy.callToAction(for: .annual, displayPrice: "$39.99", trialDays: nil) == "Subscribe for $39.99/year")
    }

    @Test func finePrintExplainsWhatHappensAfterTheTrial() {
        #expect(PaywallCopy.finePrint(for: .annual, displayPrice: "$39.99", trialDays: 7) == "Free for 7 days, then $39.99/year. Cancel anytime in Settings.")
        #expect(PaywallCopy.finePrint(for: .lifetime, displayPrice: "$89.99", trialDays: nil) == "One-time purchase.")
    }

    @Test func missingPricesShowAPlaceholder() {
        #expect(PaywallCopy.price(for: .monthly, displayPrice: nil) == "… / month")
    }

    @Test func annualDetailCombinesMonthlyEquivalentAndTrial() {
        #expect(PaywallCopy.detail(for: .annual, monthlyEquivalent: "$3.33", trialDays: 7) == "$3.33/mo · 7 days free")
        #expect(PaywallCopy.detail(for: .annual, monthlyEquivalent: "$3.33", trialDays: nil) == "$3.33/mo")
    }

    @Test func savingsBadgeOnlyForRealSavings() {
        #expect(PaywallCopy.savingsBadge(percent: 58) == "SAVE 58%")
        #expect(PaywallCopy.savingsBadge(percent: 0) == nil)
        #expect(PaywallCopy.savingsBadge(percent: nil) == nil)
    }
}
