//
//  EditRenderingMathTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

@Suite("Edit rendering math")
struct EditRenderingMathTests {
    private let portrait = CGSize(width: 1080, height: 1920)

    @Test func cropOffsetMovesAlongTheSpareAxis() {
        let centered = CropMath.crop(in: portrait, aspect: 1, offset: 0)
        let top = CropMath.crop(in: portrait, aspect: 1, offset: -1)
        let bottom = CropMath.crop(in: portrait, aspect: 1, offset: 1)
        #expect(centered == CGRect(x: 0, y: 420, width: 1080, height: 1080))
        #expect(top.minY == 0)
        #expect(bottom.maxY == 1920)
    }

    @Test func outputKeepsTheCropOrScalesDownToTheQuality() {
        #expect(EditedComposition.outputSize(for: CGSize(width: 2160, height: 3840), shortSide: 1080) == CGSize(width: 1080, height: 1920))
        #expect(EditedComposition.outputSize(for: CGSize(width: 1080, height: 1920), shortSide: 2160) == CGSize(width: 1080, height: 1920))
        #expect(EditedComposition.outputSize(for: CGSize(width: 1081, height: 1351), shortSide: nil) == CGSize(width: 1080, height: 1350))
    }

    @Test func volumeBecomesGain() {
        #expect(AudioEnhancer.gain(forVolume: 1) == 0)
        #expect(abs(AudioEnhancer.gain(forVolume: 1.5) - 3.52) < 0.01)
        #expect(AudioEnhancer.gain(forVolume: 0) == -96)
    }
}
