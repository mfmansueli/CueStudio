//
//  LengthFitTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("LengthFit")
struct LengthFitTests {
    private let ideal: ClosedRange<TimeInterval> = 60...90

    @Test func insideTheIdealRangeFits() {
        #expect(LengthFit(seconds: 60, ideal: ideal).verdict == .fits)
        #expect(LengthFit(seconds: 75, ideal: ideal).verdict == .fits)
        #expect(LengthFit(seconds: 90, ideal: ideal).verdict == .fits)
        #expect(LengthFit(seconds: 75, ideal: ideal).fits)
    }

    @Test func shorterOrLongerSaysByHowMuch() {
        #expect(LengthFit(seconds: 48, ideal: ideal).verdict == .under(12))
        #expect(LengthFit(seconds: 98, ideal: ideal).verdict == .over(8))
        #expect(!LengthFit(seconds: 48, ideal: ideal).fits)
    }

    @Test func theRangeReadsAsClockTimes() {
        #expect(LengthFit(seconds: 75, ideal: ideal).rangeLabel == "1:00–1:30")
        #expect(LengthFit(seconds: 8, ideal: 8...15).rangeLabel == "0:08–0:15")
    }

    @Test func theLabelSaysFitsOrTheGap() {
        #expect(LengthFit(seconds: 75, ideal: ideal).label == "✓ Fits 1:00–1:30")
        #expect(LengthFit(seconds: 48, ideal: ideal).label == "12s under 1:00–1:30")
        #expect(LengthFit(seconds: 98, ideal: ideal).label == "8s over 1:00–1:30")
    }
}
