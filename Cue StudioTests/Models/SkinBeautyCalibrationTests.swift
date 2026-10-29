//
//  SkinBeautyCalibrationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// How far Skin's controls go on today's engine: every control off at 0 and growing to its top, the smoothing's intensity, scale and texture
/// apart, sizes measured on the face, and nothing that can wash the face out.
@Suite("Skin calibration (today's engine)")
struct SkinBeautyCalibrationTests {
    typealias Calibration = SkinBeautyCalibration

    @Test func aControlStaysInItsRange() {
        #expect(Calibration.clamped(-5) == 0)
        #expect(Calibration.clamped(42.5) == 42.5)
        #expect(Calibration.clamped(250) == 100)
        #expect(Calibration.clamped(.nan) == 0)
        #expect(Calibration.clamped(.infinity) == 0)
        #expect(Calibration.share(50) == 0.5)
        #expect(Calibration.range == 0...100)
    }

    // MARK: - Smoothing

    @Test func theIntensityGrowsFromNothingToAllOfTheSmoothedSkin() {
        #expect(Calibration.strength(0) == 0)
        #expect(abs(Calibration.strength(100) - 1) < 1e-9)
        var previous = -1.0
        for value in stride(from: 0.0, through: 100, by: 5) {
            #expect(Calibration.strength(value) > previous, "the intensity doesn't grow at \(value)")
            previous = Calibration.strength(value)
        }
        #expect(Calibration.strength(25) < 0.25, "the first quarter of the dial stays gentle")
    }

    @Test func theScaleGrowsWithTheDialAndIsAShareOfTheFace() {
        let small = Calibration.baseSigma(faceWidth: 400, amount: 25), large = Calibration.baseSigma(faceWidth: 400, amount: 100)
        #expect(large > small)
        #expect(Calibration.baseSigma(faceWidth: 800, amount: 100) == large * 2, "a 4K face is smoothed like a 1080p one")
        #expect(Calibration.baseSigma(faceWidth: 10, amount: 0) == 1, "never under a pixel")
        #expect(Calibration.grainSigma(faceWidth: 800) == Calibration.grainSigma(faceWidth: 400) * 2)
        #expect(Calibration.grainSigma(faceWidth: 10) == 0.5)
        #expect(Calibration.edgeLevel(amount: 100) > Calibration.edgeLevel(amount: 50))
        #expect(Calibration.edgeLevel(amount: 50) > Calibration.edgeLevel(amount: 0))
        #expect(Calibration.edgeLevel(amount: 100) < 0.2501, "an edge a quarter brighter than the skin around it always stays")
    }

    @Test func theTextureIsKeptApartFromTheIntensity() {
        #expect(Calibration.textureKept(0) == 0.15, "even at 0 a little grain stays")
        #expect(abs(Calibration.textureKept(100) - 1) < 1e-9, "at 100 all of it, and never more: texture is not sharpening")
        #expect(Calibration.textureKept(50) > Calibration.textureKept(25))
        #expect(Calibration.textureKept(Calibration.defaultTexture) == Calibration.textureKept(50))
    }

    @Test func noiseIsNeverKeptAsAnEdge() {
        #expect(Calibration.noiseLevel(0.02) > 0.02)
        #expect(Calibration.noiseLevel(-1) == 0)
    }

    @Test func updatingAnEarlierSmoothingKeepsItAboutAsStrong() {
        #expect(Calibration.updatedAmount(fromFirstEngine: 0) == 0)
        #expect(Calibration.updatedAmount(fromFirstEngine: 100) == 65)
        #expect(Calibration.updatedAmount(fromFirstEngine: 50) == 33)
        #expect(Calibration.updatedAmount(fromFirstEngine: 400) == 65, "the earlier dial is kept in its range first")
        #expect(Calibration.updatedAmount(fromFirstEngine: .nan) == 0)
    }

    // MARK: - Face light and anti-shine

    @Test func theFaceLightGrowsAndNeverWashesTheFaceOut() {
        #expect(Calibration.light(0) == 0)
        #expect(Calibration.light(100) == Calibration.maximumLight)
        #expect(Calibration.light(50) < Calibration.light(100) / 2, "gentle in the first half")
        // The gain is 1 + L·4m(1 − m): it keeps rising up to white only while L < ¼.
        #expect(Calibration.maximumLight < 0.25)
        #expect(Calibration.lightFeather > 0)
    }

    @Test func theAntiShineGrowsAndNeverTakesTheShineOffWhole() {
        #expect(Calibration.shineReduction(0) == 0)
        #expect(Calibration.shineReduction(100) == Calibration.maximumShineReduction)
        #expect(Calibration.shineReduction(50) > 0 && Calibration.shineReduction(50) < Calibration.maximumShineReduction)
        #expect(Calibration.maximumShineReduction < 1, "a matte face, not a flat one")
        #expect(Calibration.shineSize * 2 < 0.25, "a lit cheek is wider than a shine")
    }

    // MARK: - Trust

    @Test func aDoubtfulFaceGetsNoneAndASureOneAllOfIt() {
        #expect(Calibration.trust(0) == 0)
        #expect(Calibration.trust(Calibration.doubtfulFace) == 0)
        #expect(Calibration.trust(Calibration.sureFace) == 1)
        #expect(Calibration.trust(1) == 1)
        #expect(Calibration.trust(.nan) == 0)
        let middle = Calibration.trust((Calibration.doubtfulFace + Calibration.sureFace) / 2)
        #expect(middle > 0.4 && middle < 0.6)
    }
}
