//
//  ExportFrameSizeTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Testing
@testable import Cue_Studio

/// The file's real size (bug 10): the format's crop of the upright recording, brought to the quality's short side, never enlarged.
@Suite("ExportFrameSize")
struct ExportFrameSizeTests {
    private let landscape = CGSize(width: 1920, height: 1080)
    private let portrait = CGSize(width: 1080, height: 1920)

    @Test func aLandscapeRecordingCroppedUprightKeepsItsOwnPixels() {
        #expect(ExportFrameSize.size(uprightSize: landscape, aspect: .portrait, shortSide: nil) == CGSize(width: 606, height: 1080))
        #expect(ExportFrameSize.size(uprightSize: landscape, aspect: .vertical, shortSide: nil) == CGSize(width: 864, height: 1080))
        #expect(ExportFrameSize.size(uprightSize: landscape, aspect: .square, shortSide: nil) == CGSize(width: 1080, height: 1080))
        #expect(ExportFrameSize.size(uprightSize: landscape, aspect: .landscape, shortSide: nil) == landscape)
    }

    @Test func aPortraitRecordingIsUnchangedInItsOwnShape() {
        #expect(ExportFrameSize.size(uprightSize: portrait, aspect: .portrait, shortSide: nil) == portrait)
        #expect(ExportFrameSize.size(uprightSize: portrait, aspect: .vertical, shortSide: nil) == CGSize(width: 1080, height: 1350))
        #expect(ExportFrameSize.size(uprightSize: portrait, aspect: .landscape, shortSide: nil) == CGSize(width: 1080, height: 606))
    }

    /// 1080p from a 4K recording scales the crop down; asking for more than the crop has never enlarges it.
    @Test func theQualityScalesDownAndNeverUp() {
        let fourK = CGSize(width: 3840, height: 2160)
        #expect(ExportFrameSize.size(uprightSize: fourK, aspect: .portrait, shortSide: 1080) == CGSize(width: 1080, height: 1920))
        #expect(ExportFrameSize.size(uprightSize: landscape, aspect: .portrait, shortSide: 2160) == CGSize(width: 606, height: 1080))
        // The export's own (`EditedComposition.outputSize`) is this rule.
        #expect(EditedComposition.outputSize(for: CGSize(width: 606, height: 1080), shortSide: 1080) == CGSize(width: 606, height: 1080))
    }

    @Test func onlyAFileSmallerThanItsQualityIsSaid() {
        #expect(ExportFrameSize.reduced(CGSize(width: 606, height: 1080), nominalShortSide: 1080) == CGSize(width: 606, height: 1080))
        #expect(ExportFrameSize.reduced(CGSize(width: 1080, height: 1920), nominalShortSide: 1080) == nil)
        #expect(ExportFrameSize.reduced(CGSize(width: 1080, height: 1350), nominalShortSide: 1080) == nil)
        #expect(ExportFrameSize.reduced(CGSize(width: 1214, height: 2160), nominalShortSide: 2160) == CGSize(width: 1214, height: 2160))
        #expect(ExportFrameSize.label(CGSize(width: 606, height: 1080)) == "606×1080")
        // Only the crop's doing counts: a recording smaller than its quality's name (a 144×256 file called 1080p) says nothing in its shape.
        #expect(ExportFrameSize.reducedByCrop(uprightSize: landscape, aspect: .portrait, shortSide: nil, nominalShortSide: 1080)
            == CGSize(width: 606, height: 1080))
        #expect(ExportFrameSize.reducedByCrop(
            uprightSize: CGSize(width: 144, height: 256), aspect: .portrait, shortSide: nil, nominalShortSide: 1080
        ) == nil)
        #expect(ExportFrameSize.reducedByCrop(uprightSize: portrait, aspect: .vertical, shortSide: nil, nominalShortSide: 1080) == nil)
        #expect(ExportFrameSize.note(CGSize(width: 606, height: 1080)) == "This format exports at 606×1080 · never enlarged")
    }
}
