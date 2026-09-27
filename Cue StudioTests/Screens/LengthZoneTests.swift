//
//  LengthZoneTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("LengthZone")
struct LengthZoneTests {
    private let tikTok = TestData.preset(.tiktok)
    private let reels = TestData.preset(.reels)

    @Test func belowTheMinimumCountsDownToMonetization() {
        let zone = LengthZone(text: TestData.words(100), preset: tikTok, speed: 1)
        #expect(zone.isBelowMinimum)
        #expect(!zone.isInIdealRange)
        #expect(zone.status == "20s to monetize")
    }

    @Test func atTheMinimumIsInTheIdealRange() {
        let zone = LengthZone(text: TestData.words(150), preset: tikTok, speed: 1)
        #expect(zone.isInIdealRange)
        #expect(zone.status == "In the ideal range")
    }

    @Test func overTheIdealRange() {
        let zone = LengthZone(text: TestData.words(200), preset: reels, speed: 1)
        #expect(zone.status == "20s over ideal")
    }

    @Test func underTheIdealRangeWithoutMinimum() {
        let zone = LengthZone(text: TestData.words(25), preset: reels, speed: 1)
        #expect(zone.status == "5s under ideal")
    }

    @Test func meterScaleLeavesRoomPastTheIdealRange() {
        let zone = LengthZone(text: TestData.words(150), preset: tikTok, speed: 1)
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
