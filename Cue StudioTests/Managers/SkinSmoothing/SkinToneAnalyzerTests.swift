//
//  SkinToneAnalyzerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A face's own skin tone and noise, measured on bytes.
@Suite("Skin tone analyzer")
struct SkinToneAnalyzerTests {
    private func bitmap(count: Int, color: (UInt8, UInt8, UInt8)) -> [UInt8] {
        (0..<count).flatMap { _ in [color.0, color.1, color.2, 255] }
    }

    @Test func theToneOfASolidSkinColorIsItsOwnChromaAndBrightness() throws {
        let rgba = bitmap(count: 400, color: (214, 160, 135))
        let tone = try #require(SkinToneAnalyzer.measure(rgba: rgba, core: [UInt8](repeating: 255, count: 400), noise: 0.01))
        let expected = SkinToneAnalyzer.chroma(red: 214.0 / 255, green: 160.0 / 255, blue: 135.0 / 255)
        #expect(abs(tone.cb - expected.cb) < 0.000_1 && abs(tone.cr - expected.cr) < 0.000_1 && abs(tone.luma - expected.luma) < 0.000_1)
        #expect(tone.noise == 0.01)
        #expect(tone.chromaReach >= 0.05 && tone.chromaReach <= 0.12)
    }

    @Test func skinChromaIsMuchTheSameInLightAndDarkSkin() throws {
        let light = SkinToneAnalyzer.chroma(red: 0.95, green: 0.78, blue: 0.68)
        let dark = SkinToneAnalyzer.chroma(red: 0.36, green: 0.22, blue: 0.16)
        #expect(light.luma > dark.luma + 0.4)
        // Both lean red and away from blue: the same quarter of the chroma plane.
        #expect(light.cr > 0 && dark.cr > 0 && light.cb < 0 && dark.cb < 0)
    }

    @Test func onlyThePixelsTheCoreMarksCount() throws {
        var rgba = bitmap(count: 400, color: (214, 160, 135))
        var core = [UInt8](repeating: 0, count: 400)
        // 200 skin pixels in the core; the others (hair, dark) are outside it.
        for index in 0..<200 { core[index] = 255 }
        for index in 200..<400 { rgba[index * 4] = 20; rgba[index * 4 + 1] = 15; rgba[index * 4 + 2] = 14 }
        let tone = try #require(SkinToneAnalyzer.measure(rgba: rgba, core: core, noise: 0))
        #expect(tone.luma > 0.6, "the dark pixels outside the core didn't pull the brightness down")
    }

    @Test func theMiddleIsRobustToSomeBeardInsideTheCore() throws {
        var rgba = bitmap(count: 400, color: (214, 160, 135))
        for index in 0..<100 { rgba[index * 4] = 70; rgba[index * 4 + 1] = 50; rgba[index * 4 + 2] = 45 }
        let tone = try #require(SkinToneAnalyzer.measure(rgba: rgba, core: [UInt8](repeating: 255, count: 400), noise: 0))
        #expect(abs(tone.luma - SkinToneAnalyzer.chroma(red: 214.0 / 255, green: 160.0 / 255, blue: 135.0 / 255).luma) < 0.000_1)
    }

    @Test func tooFewSurelySkinPixelsGiveNoTone() {
        let rgba = bitmap(count: 400, color: (214, 160, 135))
        var core = [UInt8](repeating: 0, count: 400)
        for index in 0..<(SkinToneAnalyzer.minimumSamples - 1) { core[index] = 255 }
        #expect(SkinToneAnalyzer.measure(rgba: rgba, core: core, noise: 0) == nil)
        #expect(SkinToneAnalyzer.measure(rgba: [], core: [], noise: 0) == nil)
    }

    @Test func aFlatPatchHasNoNoiseAndAGrainyOneHasItsOwn() {
        let flat = [UInt8](repeating: 128, count: 32 * 32)
        #expect(SkinToneAnalyzer.noise(green: flat, width: 32) == 0)
        var seed: UInt64 = 12_345
        let grainy = (0..<(32 * 32)).map { _ -> UInt8 in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return UInt8(128 + Int((seed >> 33) % 17) - 8)
        }
        let measured = SkinToneAnalyzer.noise(green: grainy, width: 32)
        // Uniform in ±8: a standard deviation of about 4.9 of 255.
        #expect(measured > 0.012 && measured < 0.035, "\(measured)")
    }

    @Test func aStepEdgeIsNotNoise() {
        var patch = [UInt8](repeating: 60, count: 32 * 32)
        for row in 0..<32 { for column in 16..<32 { patch[row * 32 + column] = 200 } }
        #expect(SkinToneAnalyzer.noise(green: patch, width: 32) < 0.005, "the robust estimate ignores a few edge pixels")
    }

    @Test func tooSmallAPatchHasNoNoiseToMeasure() {
        #expect(SkinToneAnalyzer.noise(green: [1, 2, 3], width: 3) == 0)
        #expect(SkinToneAnalyzer.noise(green: [UInt8](repeating: 0, count: 10), width: 3) == 0)
    }
}
