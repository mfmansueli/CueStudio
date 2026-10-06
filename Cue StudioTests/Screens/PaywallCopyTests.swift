//
//  PaywallCopyTests.swift
//  Cue StudioTests
//

import Foundation
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

    @Test func theBoardsSixLinesAreListedInOrder() {
        #expect(PaywallCopy.benefits.map(\.tag) == ["EXPORT", "AI", "AI", "EDIT", "STUDIO", "UNIVERSE"])
        #expect(PaywallCopy.benefits.first?.text == "Unlimited exports, up to 4K")
        #expect(PaywallCopy.benefits.last?.mark == "✦")
        #expect(ProPlan.allCases == [.annual, .monthly])
    }

    /// The paywall never sells what the app can't do: the Apple Watch and Mac remote stays out until it exists.
    @Test func aLineForSomethingThatIsNotThereIsNotShown() {
        let shown = PaywallCopy.visibleBenefits(aiIsAvailable: true).map(\.text).joined(separator: " ")
        #expect(!shown.contains("Apple Watch"))
        #expect(!shown.contains("watermark"))
        #expect(PaywallCopy.visibleBenefits(aiIsAvailable: true).count == PaywallCopy.benefits.count - 1)
    }

    @Test func titlesByContext() {
        #expect(PaywallCopy.title(for: .export) == "Keep sharing your universe.")
        #expect(PaywallCopy.title(for: .profile) == "Take your universe further.")
        #expect(PaywallCopy.eyebrow(for: .export) == "YOUR VIDEO IS READY")
        #expect(PaywallCopy.eyebrow(for: .profile) == "CUE PRO")
        #expect(PaywallCopy.subtitle(for: .export) == "Start the trial and export it now.")
    }

    @Test func theCalmProOffersTheTrialAndTheExportTogether() {
        #expect(PaywallCopy.callToAction(for: .annual, displayPrice: "$39.99", trialDays: 7, context: .export) == "Start free trial · export now")
        #expect(PaywallCopy.callToAction(for: .annual, displayPrice: "$39.99", trialDays: 7, context: .profile) == "Start 7-day free trial")
        #expect(PaywallCopy.welcome(for: .export, startedTrial: true) == "Trial started · video exported")
    }

    @Test func theLinesAboutAIStayOutWhereItCannotRun() {
        let withAI = PaywallCopy.visibleBenefits(aiIsAvailable: true)
        let without = PaywallCopy.visibleBenefits(aiIsAvailable: false)
        #expect(without.count == withAI.count - 2)
        #expect(without.allSatisfy { $0.tone != .ai })
    }

    @Test func theMilestoneIconsAreListedAsWhatProChanges() {
        #expect(PaywallCopy.visibleBenefits(aiIsAvailable: false).last?.text == "Every milestone app icon")
    }

    @Test func theRegularProSaysItIsFreeToTry() {
        #expect(PaywallCopy.subtitle(for: .profile) == "Free to try · 5 exports included. Then 7 days free.")
    }
}
