//
//  OrbSliderMathTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// What a slider does with its value.
@Suite("OrbSliderMath")
struct OrbSliderMathTests {
    private let speed = OrbSliderMath(range: 80...220, defaultValue: 150)
    private let size = OrbSliderMath(range: 0...3, step: 1, defaultValue: 1)

    @Test func theFractionRunsFromZeroToOne() {
        #expect(speed.fraction(of: 80) == 0)
        #expect(speed.fraction(of: 220) == 1)
        #expect(abs(speed.fraction(of: 150) - 0.5) < 0.0001)
        #expect(speed.fraction(of: 10) == 0 && speed.fraction(of: 999) == 1)
    }

    @Test func aFractionBecomesAValueInsideTheRange() {
        #expect(speed.value(atFraction: 0.5) == 150)
        #expect(speed.value(atFraction: -3) == 80)
        #expect(speed.value(atFraction: 4) == 220)
    }

    @Test func steppedValuesSnapToTheNearestStep() {
        #expect(size.snapped(1.4) == 1)
        #expect(size.snapped(1.6) == 2)
        #expect(size.snapped(9) == 3)
        #expect(size.value(atFraction: 0.5) == 2 || size.value(atFraction: 0.5) == 1)
        #expect(size.stepCount == 4)
        #expect(size.stepFractions == [0, 1.0 / 3, 2.0 / 3, 1])
        #expect(size.stepIndex(of: 2.2) == 2)
    }

    @Test func aZeroOrNegativeStepIsContinuous() {
        let math = OrbSliderMath(range: 0...10, step: 0)
        #expect(math.step == nil)
        #expect(math.snapped(3.3) == 3.3)
    }

    @Test func theDefaultValueIsKeptInsideTheRange() {
        #expect(OrbSliderMath(range: 0...10, defaultValue: 50).defaultValue == 10)
    }

    // MARK: - Dragging

    @Test func theThumbFollowsTheFingerOneToOne() {
        // A 280 pt rail over a 140-wide range: 28 pt is 14 units.
        let value = speed.value(anchor: 100, translation: 28, railLength: 280)
        #expect(abs(value - 114) < 0.0001)
    }

    @Test func finePrecisionHalvesAndQuartersTheMovement() {
        let half = speed.value(anchor: 100, translation: 28, railLength: 280, precision: .half)
        let quarter = speed.value(anchor: 100, translation: 28, railLength: 280, precision: .quarter)
        #expect(abs(half - 107) < 0.0001)
        #expect(abs(quarter - 103.5) < 0.0001)
    }

    @Test func slidingDownWhileHoldingRaisesThePrecision() {
        #expect(speed.precision(forVerticalDrag: 0) == .full)
        #expect(speed.precision(forVerticalDrag: OrbSliderMath.halfDistance + 1) == .half)
        #expect(speed.precision(forVerticalDrag: OrbSliderMath.quarterDistance + 1) == .quarter)
        #expect(OrbSliderMath.Precision.half.label == "FINE · ½" && OrbSliderMath.Precision.full.label == nil)
    }

    @Test func aControlWithAFewStepsHasNoFineMode() {
        #expect(size.precision(forVerticalDrag: 500) == .full)
    }

    @Test func aControlWithManyStepsHasFineModeAndNoDots() {
        let wpm = OrbSliderMath(range: 80...220, step: 5, defaultValue: 150)
        #expect(wpm.stepCount == 29 && !wpm.showsStepDots)
        #expect(wpm.precision(forVerticalDrag: OrbSliderMath.quarterDistance + 1) == .quarter)
        #expect(size.showsStepDots && !speed.showsStepDots)
    }

    @Test func steppedValuesAreFreeOfFloatingPointDust() {
        let clipSpeed = OrbSliderMath(range: 0.5...3, step: 0.1, defaultValue: 1)
        #expect(clipSpeed.snapped(0.5 + 0.1 * 3) == 0.8)
        #expect(clipSpeed.snapped(2.04) == 2)
    }

    @Test func aDragNeverLeavesTheRange() {
        #expect(speed.value(anchor: 200, translation: 500, railLength: 280) == 220)
        #expect(speed.value(anchor: 100, translation: -500, railLength: 280) == 80)
        #expect(speed.value(anchor: 100, translation: 10, railLength: 0) == 100)
    }

    // MARK: - Detent and ends

    @Test func theDetentTicksWhenTheThumbPassesOrLandsOnTheDefault() {
        #expect(speed.crossesDetent(from: 140, to: 160))
        #expect(speed.crossesDetent(from: 160, to: 140))
        #expect(speed.crossesDetent(from: 140, to: 150))
        #expect(!speed.crossesDetent(from: 150, to: 160))
        #expect(!speed.crossesDetent(from: 100, to: 120))
        #expect(!OrbSliderMath(range: 0...1).crossesDetent(from: 0, to: 1))
    }

    @Test func reachingAnEndIsReportedOnce() {
        #expect(speed.reachesEnd(from: 200, to: 220))
        #expect(speed.reachesEnd(from: 100, to: 80))
        #expect(!speed.reachesEnd(from: 220, to: 220))
        #expect(!speed.reachesEnd(from: 100, to: 120))
    }

    // MARK: - VoiceOver

    @Test func voiceOverMovesOneStepOnASteppedControl() {
        #expect(size.incremented(1) == 2)
        #expect(size.decremented(1) == 0)
        #expect(size.incremented(3) == 3)
        #expect(size.decremented(0) == 0)
    }

    @Test func voiceOverMovesAWholeNumberOfStepsOnAControlWithManySteps() {
        let percent = OrbSliderMath(range: 0...100, step: 1, defaultValue: 70)
        #expect(percent.accessibilityStep == 5)
        let wpm = OrbSliderMath(range: 80...220, step: 5)
        #expect(wpm.accessibilityStep == 5 && wpm.incremented(150) == 155)
        let clipSpeed = OrbSliderMath(range: 0.5...3, step: 0.1)
        #expect(abs(clipSpeed.accessibilityStep - 0.1) < 1e-9 || abs(clipSpeed.accessibilityStep - 0.2) < 1e-9)
    }

    @Test func voiceOverMovesFivePercentOnAContinuousControl() {
        #expect(abs(speed.incremented(100) - 107) < 0.0001)
        #expect(abs(speed.decremented(100) - 93) < 0.0001)
        #expect(speed.incremented(219) == 220)
        #expect(speed.decremented(81) == 80)
    }
}
