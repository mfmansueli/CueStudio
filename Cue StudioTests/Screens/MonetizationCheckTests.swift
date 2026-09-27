//
//  MonetizationCheckTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("MonetizationCheck")
struct MonetizationCheckTests {
    private let tikTok = TestData.preset(.tiktok)
    private let reels = TestData.preset(.reels)

    @Test func countsDownToTheMinimum() {
        #expect(MonetizationCheck.secondsMissing(elapsed: 42, preset: tikTok) == 18)
        #expect(MonetizationCheck.chipLabel(elapsed: 42, preset: tikTok) == "18s to 1:00")
        #expect(MonetizationCheck.warningTitle(elapsed: 42, preset: tikTok) == "18s short of 1:00")
    }

    @Test func pastTheMinimumIsMonetizable() {
        #expect(MonetizationCheck.secondsMissing(elapsed: 61, preset: tikTok) == nil)
        #expect(MonetizationCheck.chipLabel(elapsed: 61, preset: tikTok) == "✓ Monetizable")
        #expect(MonetizationCheck.warningTitle(elapsed: 61, preset: tikTok) == nil)
    }

    @Test func platformsWithoutMinimumNeverWarn() {
        #expect(MonetizationCheck.secondsMissing(elapsed: 5, preset: reels) == nil)
        #expect(MonetizationCheck.chipLabel(elapsed: 5, preset: reels) == nil)
        #expect(MonetizationCheck.secondsMissing(elapsed: 5, preset: nil) == nil)
    }
}
