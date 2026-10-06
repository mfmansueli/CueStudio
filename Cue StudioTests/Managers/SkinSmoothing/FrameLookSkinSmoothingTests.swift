//
//  FrameLookSkinSmoothingTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// Where Skin Smoothing sits in the look: after Auto, before the dials and the filter, independent of the filter picked, and never changing how a
/// filter looks when it is off.
@Suite("Frame look with Skin Smoothing", .serialized, .timeLimit(.minutes(5)))
struct FrameLookSkinSmoothingTests {
    private static let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
    private static let image = SkinFaceFixture.image()
    private static let bounds = CGRect(origin: .zero, size: SkinFaceFixture.size)
    private static let pass = SkinSmoother(context: context, detector: FakeFaceDetector(faces: [SkinFaceFixture.landmarks()]))
        .pass(for: image, stream: .main, epoch: 0, time: 0)

    private func look(filter: VideoFilter = .original, skin: Double = 0, exposure: Double = 0) -> LookSettings {
        var look = LookSettings()
        look.filter = filter
        look.skinSmoothing = skin
        look.exposure = exposure
        return look
    }

    private func render(_ look: LookSettings, skin: SkinSmoothingPass?) -> RenderedPixels {
        RenderedPixels(FrameLook.apply(look, to: Self.image, skin: skin))
    }

    @Test func everyFilterDrawsTheSameWithSmoothingOffWhateverTheFacesFound() {
        for filter in [VideoFilter.natural, .studio, .vivid, .mono] {
            let plain = render(look(filter: filter), skin: nil)
            let withFaces = render(look(filter: filter, skin: 0), skin: Self.pass)
            #expect(plain.greatestDifference(from: withFaces, in: Self.bounds) == 0, "\(filter) changed with the dial at 0")
        }
    }

    @Test func aDialAboveZeroWithNoFaceTouchesNothing() {
        let plain = render(look(filter: .studio, exposure: 10), skin: nil)
        let none = render(look(filter: .studio, skin: 80, exposure: 10), skin: SkinSmoothingPass.none)
        #expect(plain.greatestDifference(from: none, in: Self.bounds) == 0)
        let withoutAPass = render(look(filter: .studio, skin: 80, exposure: 10), skin: nil)
        #expect(plain.greatestDifference(from: withoutAPass, in: Self.bounds) == 0, "no pass, no smoothing: filter previews and the like")
    }

    @Test func smoothingIsIndependentOfTheFilterPicked() {
        let cheek = SkinFaceFixture.cheek
        for filter in [VideoFilter.original, .natural, .studio, .vivid] {
            let off = render(look(filter: filter), skin: Self.pass).texture(in: cheek)
            let on = render(look(filter: filter, skin: 100), skin: Self.pass).texture(in: cheek)
            #expect(on < off * 0.9, "\(filter): \(off) → \(on)")
        }
    }

    @Test func smoothingComesBeforeTheFilterAndTheDials() {
        let cheek = SkinFaceFixture.cheek
        // The skin is smoothed from the picture as recorded, then graded: the same as grading what was smoothed.
        let both = render(look(filter: .studio, skin: 100, exposure: 20), skin: Self.pass)
        let smoothed = FrameLook.apply(look(skin: 100), to: Self.image, skin: Self.pass)
        let thenGraded = RenderedPixels(FrameLook.apply(look(filter: .studio, exposure: 20), to: smoothed))
        #expect(both.greatestDifference(from: thenGraded, in: Self.bounds) <= 2)
        // Smoothing a picture already turned to black and white finds no skin tone to work on, so it would do nearly nothing: it can't come after.
        let gradedFirst = FrameLook.apply(look(filter: .mono), to: Self.image)
        let thenSmoothed = RenderedPixels(Self.pass.apply(value: 100, to: gradedFirst))
        let smoothedFirst = render(look(filter: .mono, skin: 100), skin: Self.pass)
        #expect(smoothedFirst.texture(in: cheek) < thenSmoothed.texture(in: cheek) * 0.97)
    }

    @Test func theTakesLookReachesTheSmoothingOfTheClipThatPlays() {
        var take = TakeEdit(sourceDuration: 20, aspect: .portrait)
        take.skinSmoothing = 70
        var clip = take.timeline.segments[0]
        #expect(take.lookSettings(for: clip).skinSmoothing == 70)
        var override = ClipLook()
        override.skinSmoothing = 0
        clip.look = override
        let cheek = SkinFaceFixture.cheek
        let off = RenderedPixels(FrameLook.apply(take.lookSettings(for: clip), to: Self.image, skin: Self.pass)).texture(in: cheek)
        let on = RenderedPixels(FrameLook.apply(LookSettings(take), to: Self.image, skin: Self.pass)).texture(in: cheek)
        #expect(on < off, "the clip that turned it off is not smoothed, the take is")
    }
}
