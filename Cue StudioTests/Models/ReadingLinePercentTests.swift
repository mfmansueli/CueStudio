//
//  ReadingLinePercentTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

/// The reading line as a percent of the screen's height, measured where the slider is.
@Suite("ReadingLinePercent")
struct ReadingLinePercentTests {
    private let scale = ReadingLinePercent(screenHeight: 800, lensY: 30)

    @Test func aPercentBecomesPointsBelowTheLens() {
        #expect(scale.placement(forPercent: 22) == .offset(146))
        #expect(scale.placement(forPercent: 50) == .offset(370))
    }

    @Test func aPlacementBecomesAPercentHeldToTheRange() {
        #expect(scale.percent(for: .offset(146)) == 22)
        #expect(scale.percent(for: .offset(0)) == 10, "a line above the range shows at the camera end")
        #expect(scale.percent(for: .offset(600)) == 50)
    }

    @Test func theRecommendedSpotShowsWhereItSits() {
        // 30 + 118 = 148 pt of 800: 18.5% → 19%.
        #expect(scale.percent(for: .recommended) == 19)
    }

    @Test func aPercentOutsideTheRangeIsHeld() {
        #expect(scale.placement(forPercent: 90) == scale.placement(forPercent: 50))
        #expect(scale.placement(forPercent: 1) == scale.placement(forPercent: 10))
    }

    @Test func theSameSliderMeansTheSameRelativePlaceOnAnotherScreen() {
        let tall = ReadingLinePercent(screenHeight: 932, lensY: 31)
        let short = ReadingLinePercent(screenHeight: 667, lensY: 10)
        let tallLine = 31 + (tall.placement(forPercent: 30).offset ?? 0)
        let shortLine = 10 + (short.placement(forPercent: 30).offset ?? 0)
        #expect(abs(tallLine / 932 - shortLine / 667) < 0.002)
    }
}
