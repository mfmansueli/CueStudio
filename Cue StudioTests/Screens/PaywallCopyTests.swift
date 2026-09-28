//
//  PaywallCopyTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("PaywallCopy")
struct PaywallCopyTests {
    @Test func bothPlansStartWithTheTrial() {
        #expect(PaywallCopy.callToAction(for: .annual, displayPrice: "$39.99", trialDays: 7) == "Start 7-day free trial")
        #expect(PaywallCopy.callToAction(for: .monthly, displayPrice: "$7.99", trialDays: 7) == "Start 7-day free trial")
        #expect(PaywallCopy.callToAction(for: .annual, displayPrice: "$39.99", trialDays: nil) == "Subscribe for $39.99/year")
        #expect(PaywallCopy.callToAction(for: .monthly, displayPrice: "$7.99", trialDays: nil) == "Subscribe for $7.99/month")
    }

    @Test func finePrintExplainsWhatHappensAfterTheTrial() {
        #expect(PaywallCopy.finePrint(for: .annual, displayPrice: "$39.99", trialDays: 7) == "Free for 7 days, then $39.99/year. Cancel anytime in Settings.")
        #expect(PaywallCopy.finePrint(for: .monthly, displayPrice: "$7.99", trialDays: 7) == "Free for 7 days, then $7.99/month. Cancel anytime in Settings.")
        #expect(PaywallCopy.finePrint(for: .monthly, displayPrice: "$7.99", trialDays: nil) == "Renews monthly at $7.99. Cancel anytime in Settings.")
    }

    @Test func missingPricesShowAPlaceholder() {
        #expect(PaywallCopy.price(for: .monthly, displayPrice: nil) == "… / month")
    }

    @Test func planDetails() {
        #expect(PaywallCopy.detail(for: .annual, monthlyEquivalent: "$3.33", trialDays: 7) == "$3.33/mo · 7 days free")
        #expect(PaywallCopy.detail(for: .annual, monthlyEquivalent: "$3.33", trialDays: nil) == "$3.33/mo")
        #expect(PaywallCopy.detail(for: .monthly, monthlyEquivalent: nil, trialDays: 7) == "7 days free · cancel anytime")
        #expect(PaywallCopy.detail(for: .monthly, monthlyEquivalent: nil, trialDays: nil) == "Cancel anytime")
    }

    @Test func savingsBadgeOnlyForRealSavings() {
        #expect(PaywallCopy.savingsBadge(percent: 58) == "SAVE 58%")
        #expect(PaywallCopy.savingsBadge(percent: 0) == nil)
        #expect(PaywallCopy.savingsBadge(percent: nil) == nil)
    }

    @Test func onlyExportingIsSold() {
        let features = PaywallCopy.features.joined(separator: " ")
        #expect(features.contains("Unlimited video exports"))
        #expect(!features.contains("watermark"))
        #expect(!features.contains("Apple Watch"))
        #expect(!features.contains("iPad"))
        #expect(ProPlan.allCases == [.annual, .monthly])
    }

    @Test func titlesByContext() {
        #expect(PaywallCopy.title(for: .export) == "Keep posting with Cue")
        #expect(PaywallCopy.title(for: .profile) == "Create more. Sound like you.")
        #expect(PaywallCopy.subtitle(for: .export).contains("5 free exports"))
    }
}
