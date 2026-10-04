//
//  CueSliderMathTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("CueSlider math")
struct CueSliderMathTests {
    private let speed = 0.3...2.0

    @Test func theThumbIsAtTheEndsOfTheTrackForTheEndsOfTheRange() {
        #expect(CueSliderMath.fraction(of: 0.3, in: speed) == 0)
        #expect(CueSliderMath.fraction(of: 2.0, in: speed) == 1)
        #expect(abs(CueSliderMath.fraction(of: 1.15, in: speed) - 0.5) < 0.0001)
    }

    @Test func aValueOutsideTheRangeIsHeldAtTheNearestEnd() {
        #expect(CueSliderMath.fraction(of: -4, in: speed) == 0)
        #expect(CueSliderMath.fraction(of: 9, in: speed) == 1)
        #expect(CueSliderMath.fraction(of: 1, in: 1...1) == 0)
    }

    /// The thumb's center travels from half its width to the end minus half, so a touch on the first
    /// 12 pt picks the minimum and one on the last 12 pt the maximum.
    @Test func aTouchAtEitherEndPicksTheEndValue() {
        let low = CueSliderMath.value(atX: 0, width: 224, thumb: 24, range: speed, step: 0.1)
        let high = CueSliderMath.value(atX: 224, width: 224, thumb: 24, range: speed, step: 0.1)
        #expect(low == 0.3)
        #expect(high == 2.0)
        #expect(CueSliderMath.value(atX: 12, width: 224, thumb: 24, range: speed, step: 0.1) == 0.3)
        #expect(CueSliderMath.value(atX: 212, width: 224, thumb: 24, range: speed, step: 0.1) == 2.0)
    }

    @Test func aTouchInTheMiddlePicksTheMiddleValueOnAStep() {
        let middle = CueSliderMath.value(atX: 112, width: 224, thumb: 24, range: speed, step: 0.1)
        #expect(abs(middle - 1.2) < 0.0001 || abs(middle - 1.1) < 0.0001)
        let steps = (middle - 0.3) / 0.1
        #expect(abs(steps - steps.rounded()) < 0.0001)
    }

    @Test func aTouchOutsideTheTrackIsHeldInsideTheRange() {
        #expect(CueSliderMath.value(atX: -80, width: 224, thumb: 24, range: speed, step: 0.1) == 0.3)
        #expect(CueSliderMath.value(atX: 900, width: 224, thumb: 24, range: speed, step: 0.1) == 2.0)
    }

    @Test func valuesSnapToTheStepWithoutFloatingPointDust() {
        // 0.7000000000000001 and 0.30000000000000004 are what naive arithmetic gives.
        #expect(CueSliderMath.snapped(0.3 + 0.1 + 0.1 + 0.1 + 0.1, step: 0.1, in: speed) == 0.7)
        #expect(CueSliderMath.snapped(0.74, step: 0.1, in: speed) == 0.7)
        #expect(CueSliderMath.snapped(0.76, step: 0.1, in: speed) == 0.8)
        #expect(CueSliderMath.snapped(5, step: 0.1, in: speed) == 2.0)
        #expect(CueSliderMath.snapped(0, step: 0.1, in: speed) == 0.3)
    }

    @Test func aTrackNarrowerThanTheThumbHasOnlyTheMinimum() {
        #expect(CueSliderMath.value(atX: 10, width: 20, thumb: 24, range: speed, step: 0.1) == 0.3)
    }
}
