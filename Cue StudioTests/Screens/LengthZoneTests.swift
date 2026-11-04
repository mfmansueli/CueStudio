//
//  LengthZoneTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("LengthZone")
struct LengthZoneTests {
    // At the natural pace (150 words a minute, whatever the prompter's speed), 30 words take 12 seconds.
    private let tikTok = TestData.preset(.tiktok)
    private let reels = TestData.preset(.reels)

    @Test func belowTheMinimumCountsDownToMonetization() {
        let zone = LengthZone(text: TestData.words(90), preset: tikTok)
        #expect(zone.isBelowMinimum)
        #expect(!zone.isInIdealRange)
        #expect(zone.status == "24s to the length goal")
    }

    /// TikTok's ideal is 1:15–2:30 (the owner's call, 04/11/2026): 200 words take 1:20.
    @Test func withinTheIdealRange() {
        let zone = LengthZone(text: TestData.words(200), preset: tikTok)
        #expect(zone.isInIdealRange)
        #expect(zone.status == "In the ideal range")
    }

    @Test func pastTheMinimumButShortOfTheIdeal() {
        let zone = LengthZone(text: TestData.words(150), preset: tikTok)
        #expect(!zone.isBelowMinimum && !zone.isInIdealRange)
        #expect(zone.status == "15s under ideal")
    }

    @Test func overTheIdealRange() {
        // Reels' ideal is 1:15–2:30: 400 words take 2:40.
        let zone = LengthZone(text: TestData.words(400), preset: reels)
        #expect(zone.status == "10s over ideal")
    }

    @Test func underTheIdealRangeWithoutMinimum() {
        let zone = LengthZone(text: TestData.words(180), preset: reels)
        #expect(zone.status == "3s under ideal")
    }

    @Test func meterScaleLeavesRoomPastTheIdealRange() {
        let zone = LengthZone(text: TestData.words(150), preset: tikTok)
        #expect(abs(zone.scaleMax - 180) < 0.0001)
        #expect(abs((zone.minimumFraction ?? 0) - 60.0 / 180.0) < 0.0001)
        #expect(zone.minimumLabel == "1:00 · Creator Rewards")
    }

    @Test func emptyScriptShowsZeroSeconds() {
        let zone = LengthZone(text: "", preset: reels)
        #expect(zone.durationLabel == "0s")
        #expect(zone.words == 0)
    }
}
