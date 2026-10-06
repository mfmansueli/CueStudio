//
//  SkinSmoothingCalibrationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// How far the Skin Smoothing dial goes: conservative at the top, off at 0, and measured on the face, not on the frame.
@Suite("Skin Smoothing calibration")
struct SkinSmoothingCalibrationTests {
    typealias Calibration = SkinSmoothingCalibration

    @Test func theDialStaysInItsRange() {
        #expect(Calibration.clamped(-5) == 0)
        #expect(Calibration.clamped(0) == 0)
        #expect(Calibration.clamped(42.5) == 42.5)
        #expect(Calibration.clamped(100) == 100)
        #expect(Calibration.clamped(250) == 100)
        #expect(Calibration.clamped(.nan) == 0)
        #expect(Calibration.clamped(.infinity) == 0)
        #expect(Calibration.range == 0...100)
    }

    @Test func zeroIsOffAndAnythingAboveItIsOn() {
        #expect(!Calibration.isOn(0))
        #expect(!Calibration.isOn(-20))
        #expect(!Calibration.isOn(.nan))
        #expect(Calibration.isOn(1))
        #expect(Calibration.isOn(100))
        #expect(Calibration.strength(0) == 0)
    }

    @Test func theStrengthGrowsWithTheDialAndStopsWellShortOfFull() {
        var previous = -1.0
        for value in stride(from: 0.0, through: 100, by: 5) {
            let strength = Calibration.strength(value)
            #expect(strength > previous, "the strength doesn't grow at \(value)")
            previous = strength
        }
        #expect(Calibration.strength(100) == Calibration.maximumStrength)
        #expect(Calibration.maximumStrength <= 0.65, "a conservative top: the picture always shows through")
        // Eased: the first half of the dial is a fine-tuning, less than half of the strength.
        #expect(Calibration.strength(50) < Calibration.strength(100) / 2)
        #expect(Calibration.strength(300) == Calibration.strength(100))
    }

    @Test func theBlurFollowsTheFaceAndNotTheFrame() {
        for value in [10.0, 50, 100] {
            let narrow = Calibration.blurSigma(faceWidth: 400, value: value)
            let wide = Calibration.blurSigma(faceWidth: 800, value: value)
            #expect(abs(wide - narrow * 2) < 0.000_1, "a face twice as wide (4K) has twice the blur")
        }
        #expect(Calibration.blurSigma(faceWidth: 400, value: 100) > Calibration.blurSigma(faceWidth: 400, value: 0))
        #expect(Calibration.blurSigma(faceWidth: 400, value: 100) < 5, "never past the scale of pores and blemishes")
        #expect(Calibration.blurSigma(faceWidth: 20, value: 0) == 1, "never under a pixel")
    }

    @Test func theTextureLimitsFollowTheDialTheNoiseAndTheLight() {
        let quiet = Calibration.coring(value: 50, noise: 0.002, luma: 0.55)
        #expect(quiet.edge > quiet.soft && quiet.soft > 0)
        let noisy = Calibration.coring(value: 50, noise: 0.03, luma: 0.55)
        #expect(noisy.soft > quiet.soft, "noisy skin counts more of its detail as noise")
        let stronger = Calibration.coring(value: 100, noise: 0.002, luma: 0.55)
        #expect(stronger.soft > quiet.soft && stronger.edge > quiet.edge)
        let dim = Calibration.coring(value: 50, noise: 0.002, luma: 0.2)
        #expect(dim.soft < quiet.soft && dim.edge < quiet.edge, "dark skin has smaller detail in absolute terms")
        let bright = Calibration.coring(value: 50, noise: 0.002, luma: 0.95)
        #expect(bright.soft > quiet.soft)
    }

    @Test func mostOfTheFineDetailStaysEvenWhereItIsSoftened() {
        #expect(Calibration.flatDetailKept > 0 && Calibration.flatDetailKept <= 0.5)
        // At the top of the dial a flat patch keeps at least half of its detail: 1 − strength × (1 − kept).
        #expect(1 - Calibration.maximumStrength * (1 - Calibration.flatDetailKept) >= 0.5)
    }

    @Test func facesTooSmallOrTooManyAreLeftAlone() {
        #expect(Calibration.minimumFaceShare > 0.03 && Calibration.minimumFaceShare < 0.2)
        #expect(Calibration.maximumFaces >= 2)
        #expect(Calibration.detectionInterval < 1.0 / 19 && Calibration.detectionInterval > 1.0 / 31, "about twenty looks a second")
        #expect(Calibration.holdTime > Calibration.fadeInTime / 2)
    }
}
