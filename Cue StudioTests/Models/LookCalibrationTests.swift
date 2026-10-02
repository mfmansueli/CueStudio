//
//  LookCalibrationTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The Adjust dials of the calibrated look: zero is neutral, small moves are small, the ends of a
/// dial stop short of where a picture breaks.
@Suite("Look calibration")
struct LookCalibrationTests {
    @Test func zeroIsNeutralOnEveryDial() {
        #expect(LookCalibration.exposureStops(0) == 0)
        #expect(LookCalibration.contrastStrength(0) == 0)
        #expect(LookCalibration.saturationScale(0) == 1)
        #expect(LookCalibration.vibranceAmount(0) == 0)
        #expect(abs(LookCalibration.warmthKelvin(0) - 6500) < 0.001)
        #expect(LookCalibration.tintGreenGain(0) == 1)
        #expect(LookCalibration.highlightAmount(0) == 1)
        #expect(LookCalibration.highlightLift(0) == 0)
        #expect(LookCalibration.shadowAmount(0) == 0)
        #expect(LookCalibration.sharpness(0) == 0)
    }

    @Test func smallMovesAreFinerThanTheFirstReading() {
        // The first reading: exposure ±100 = 1.2 stops, linear.
        #expect(LookCalibration.exposureStops(10) < 10.0 / 100 * 1.2)
        #expect(LookCalibration.exposureStops(10) < 0.08)
        #expect(LookCalibration.exposureStops(-10) == -LookCalibration.exposureStops(10))
        // The first reading of warmth: +25 K a step, 2500 K at the end.
        #expect(LookCalibration.warmthKelvin(10) - 6500 < 250)
    }

    @Test func theEndsOfADialAreSafe() {
        #expect(abs(LookCalibration.exposureStops(100) - 1.2) < 0.0001)
        #expect(abs(LookCalibration.saturationScale(100) - 1.7) < 0.0001)
        #expect(LookCalibration.saturationScale(-100) == 0)
        #expect(LookCalibration.warmthKelvin(100) - 6500 < 2000)
        #expect(6500 - LookCalibration.warmthKelvin(-100) < 1500)
        #expect(abs(LookCalibration.highlightAmount(-100) - 0.15) < 0.0001)
        // Shadows never go to black, and open to at most 0.8.
        #expect(LookCalibration.shadowAmount(-100) >= -0.5)
        #expect(LookCalibration.shadowAmount(100) <= 0.8)
        #expect(LookCalibration.sharpness(100) <= 0.6)
        #expect(abs(LookCalibration.tintGreenGain(100) - 0.88) < 0.0001)
        #expect(abs(LookCalibration.tintGreenGain(-100) - 1.12) < 0.0001)
    }

    @Test func everyDialGrowsWithItsValue() {
        let values = stride(from: -100.0, through: 100.0, by: 10.0).map { $0 }
        for function in [
            LookCalibration.exposureStops, LookCalibration.saturationScale, LookCalibration.vibranceAmount,
            LookCalibration.warmthKelvin, LookCalibration.shadowAmount, LookCalibration.contrastStrength,
        ] {
            let results = values.map(function)
            #expect(zip(results, results.dropFirst()).allSatisfy { $0 < $1 })
        }
        let sharpness = stride(from: 0.0, through: 100.0, by: 10.0).map(LookCalibration.sharpness)
        #expect(zip(sharpness, sharpness.dropFirst()).allSatisfy { $0 < $1 })
        // Highlights: the more negative, the lower the amount.
        let highlights = stride(from: -100.0, through: 0.0, by: 10.0).map(LookCalibration.highlightAmount)
        #expect(zip(highlights, highlights.dropFirst()).allSatisfy { $0 < $1 })
    }

    @Test func theContrastCurveKeepsBlackAndWhiteAndBendsTheMiddle() {
        let neutral = LookCalibration.contrastCurve(strength: 0)
        #expect(neutral.allSatisfy { abs($0.x - $0.y) < 0.000_001 })
        let more = LookCalibration.contrastCurve(strength: 1)
        #expect(more.first == CGPoint(x: 0, y: 0) && more.last == CGPoint(x: 1, y: 1))
        #expect(abs(more[2].y - 0.5) < 0.000_001)
        // More contrast: shadows darker, highlights brighter.
        #expect(more[1].y < 0.25 && more[3].y > 0.75)
        // The middle's slope changes by at most 30%.
        #expect(more[3].y - more[1].y <= 0.5 * 1.3)
        let less = LookCalibration.contrastCurve(strength: -1)
        #expect(less[1].y > 0.25 && less[3].y < 0.75)
    }

    @Test func sharpeningFollowsThePictureSizeWithinLimits() {
        #expect(LookCalibration.sharpenRadius(forWidth: 1080) == 0.9)
        #expect(LookCalibration.sharpenRadius(forWidth: 3840) > LookCalibration.sharpenRadius(forWidth: 1080))
        #expect(LookCalibration.sharpenRadius(forWidth: 100_000) == 0.9 * 2.5)
        #expect(LookCalibration.sharpenRadius(forWidth: 100) == 0.9 * 0.75)
    }
}
