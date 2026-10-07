//
//  LengthZoneTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("LengthZone")
struct LengthZoneTests {
    // At 1.0× (215 words a minute), 43 words take 12 seconds.
    private let tikTok = TestData.preset(.tiktok)
    private let reels = TestData.preset(.reels)

    @Test func belowTheMinimumCountsDownToMonetization() {
        let zone = LengthZone(text: TestData.words(129), preset: tikTok, speed: 1)
        #expect(zone.isBelowMinimum)
        #expect(!zone.isInIdealRange)
        #expect(zone.status == "24s to monetize")
    }

    @Test func atTheMinimumIsInTheIdealRange() {
        let zone = LengthZone(text: TestData.words(215), preset: tikTok, speed: 1)
        #expect(zone.isInIdealRange)
        #expect(zone.status == "In the ideal range")
    }

    @Test func overTheIdealRange() {
        // Reels' ideal is 0:30–1:30 for a spoken video: 365 words take 1:42.
        let zone = LengthZone(text: TestData.words(365), preset: reels, speed: 1)
        #expect(zone.status == "12s over ideal")
    }

    @Test func underTheIdealRangeWithoutMinimum() {
        let zone = LengthZone(text: TestData.words(97), preset: reels, speed: 1)
        #expect(zone.status == "3s under ideal")
    }

    @Test func meterScaleLeavesRoomPastTheIdealRange() {
        let zone = LengthZone(text: TestData.words(215), preset: tikTok, speed: 1)
        #expect(abs(zone.scaleMax - 108) < 0.0001)
        #expect(abs((zone.minimumFraction ?? 0) - 60.0 / 108.0) < 0.0001)
        #expect(zone.minimumLabel == "1:00 · monetizes")
    }

    @Test func emptyScriptShowsZeroSeconds() {
        let zone = LengthZone(text: "", preset: reels, speed: 1)
        #expect(zone.durationLabel == "0s")
        #expect(zone.words == 0)
    }
}
