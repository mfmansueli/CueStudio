//
//  PaywallCopyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("PaywallCopy")
struct PaywallCopyTests {
    /// No free trial (owner, 30/10/2026): the button and the small print say the price.
    @Test func theButtonSubscribesAtThePrice() {
        #expect(PaywallCopy.callToAction(for: .annual, displayPrice: "$39.99") == "Subscribe for $39.99/year")
        #expect(PaywallCopy.callToAction(for: .monthly, displayPrice: "$7.99") == "Subscribe for $7.99/month")
    }

    @Test func finePrintSaysWhenItRenews() {
        #expect(PaywallCopy.finePrint(for: .annual, displayPrice: "$39.99") == "Renews yearly at $39.99. Cancel anytime in Settings.")
        #expect(PaywallCopy.finePrint(for: .monthly, displayPrice: "$7.99") == "Renews monthly at $7.99. Cancel anytime in Settings.")
    }

    @Test func missingPricesShowAPlaceholder() {
        #expect(PaywallCopy.price(for: .monthly, displayPrice: nil) == "… / month")
    }

    @Test func savingsBadgeOnlyForRealSavings() {
        #expect(PaywallCopy.savingsBadge(percent: 58) == "SAVE 58%")
        #expect(PaywallCopy.savingsBadge(percent: 0) == nil)
        #expect(PaywallCopy.savingsBadge(percent: nil) == nil)
    }

    /// Under the two highlights (exports, Ultra AI where it is offered), only what Pro really adds (decision 12): nothing free is sold as Pro.
    @Test func theRestIsOnlyWhatProReallyAdds() {
        #expect(PaywallCopy.visibleBenefits(aiIsAvailable: true).map(\.text) == [
            "The milestone app icons from 10 videos on", "No Cue mark on screen recordings · exported videos never have one",
        ])
        #expect(ProPlan.allCases == [.annual, .monthly])
    }

    /// The paywall never sells what the app can't do, nor what is free: no Apple Watch remote, no My Cue Voice, no covers.
    @Test func noLineSellsWhatIsNotThereOrIsFree() {
        let shown = PaywallCopy.visibleBenefits(aiIsAvailable: true).map(\.text).joined(separator: " ")
        for free in ["Apple Watch", "My Cue Voice", "Covers", "Hook", "Text behind me"] { #expect(!shown.contains(free), "\(free)") }
        #expect(PaywallCopy.visibleBenefits(aiIsAvailable: true).count == PaywallCopy.benefits.count)
    }

    @Test func titlesByContext() {
        #expect(PaywallCopy.title(for: .export) == "Keep sharing your universe.")
        #expect(PaywallCopy.title(for: .profile) == "Take your universe further.")
        #expect(PaywallCopy.eyebrow(for: .export) == "YOUR VIDEO IS READY")
        #expect(PaywallCopy.eyebrow(for: .profile) == "CUE PRO")
        #expect(PaywallCopy.subtitle(for: .export) == "Subscribe and export it now.")
    }

    @Test func theCalmProSubscribesAndExportsTogether() {
        #expect(PaywallCopy.callToAction(for: .annual, displayPrice: "$39.99", context: .export) == "Subscribe · export now")
        #expect(PaywallCopy.callToAction(for: .annual, displayPrice: "$39.99", context: .profile) == "Subscribe for $39.99/year")
        #expect(PaywallCopy.welcome(for: .export) == "Welcome to Cue Pro · video exported")
        #expect(PaywallCopy.welcome(for: .ultra) == "Welcome to Cue Pro · 30 Ultra AI scripts this month")
    }

    /// None of what Pro adds needs Apple Intelligence, so every iPhone reads the same list.
    @Test func everyIPhoneReadsTheSameList() {
        #expect(PaywallCopy.visibleBenefits(aiIsAvailable: false).map(\.text) == PaywallCopy.visibleBenefits(aiIsAvailable: true).map(\.text))
    }

    /// The watermark line says exported videos never carry one: Pro removes it from screen recordings only.
    @Test func theWatermarkLineIsAboutScreenRecordings() {
        #expect(PaywallCopy.visibleBenefits(aiIsAvailable: false).last?.text.contains("screen recordings") == true)
    }

    @Test func theRegularProSaysItIsFreeToTry() {
        #expect(PaywallCopy.subtitle(for: .profile) == "Free to try · 3 exports included.")
    }

    /// Where Ultra AI is offered: its free scripts in the line under the title (its 30 a month are a highlight, `ProHighlightCard`), and its own
    /// calm Pro when they are used up.
    @Test func ultraAIIsSaidOnlyWhereItIsOffered() {
        #expect(!PaywallCopy.visibleBenefits(aiIsAvailable: true).contains { $0.text.contains("Ultra") })
        #expect(PaywallCopy.subtitle(for: .profile, ultraIsOffered: true) == "Free to try · 3 exports and 3 Ultra AI scripts included.")
        #expect(PaywallCopy.title(for: .ultra) == "Keep writing with Ultra AI.")
        #expect(PaywallCopy.eyebrow(for: .ultra) == "ULTRA AI")
        #expect(PaywallCopy.subtitle(for: .ultra) == "Your 3 free scripts are written. Cue Pro adds 30 a month.")
    }
}
