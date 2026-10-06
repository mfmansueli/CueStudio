//
//  SkinSmootherTests.swift
//  Cue StudioTests
//

import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// When the smoother looks for faces, and how it keeps them steady from frame to frame.
@Suite("Skin smoother", .serialized, .timeLimit(.minutes(3)))
struct SkinSmootherTests {
    private typealias Calibration = SkinSmoothingCalibration

    private static let context = CIContext(options: [.useSoftwareRenderer: true, .cacheIntermediates: false])
    private static let image = SkinFaceFixture.image()

    private func smoother(_ detector: FakeFaceDetector) -> SkinSmoother {
        SkinSmoother(context: Self.context, detector: detector)
    }

    private let face = SkinFaceFixture.landmarks()

    // MARK: - Off

    @Test func atZeroItNeverLooksAtThePicture() {
        let detector = FakeFaceDetector(faces: [face])
        let smoother = smoother(detector)
        #expect(smoother.pass(for: Self.image, value: 0, stream: .main, epoch: 0, time: 0) == nil)
        #expect(smoother.pass(for: Self.image, value: -3, stream: .main, epoch: 0, time: 1) == nil)
        #expect(detector.calls == 0)
        #expect(smoother.pass(for: Self.image, value: 1, stream: .main, epoch: 0, time: 2) != nil)
        #expect(detector.calls == 1)
    }

    @Test func aFrameWithNoFaceHasNothingToSmooth() throws {
        let detector = FakeFaceDetector()
        let pass = try #require(smoother(detector).pass(for: Self.image, value: 100, stream: .main, epoch: 0, time: 0))
        #expect(pass.faces.isEmpty)
    }

    @Test func aFaceTooSmallToMeasureItsSkinIsLeftAlone() throws {
        // The same face drawn at a twentieth of its size: a few pixels of skin, not enough to tell its tone from.
        let middle = CGPoint(x: SkinFaceFixture.center.x / SkinFaceFixture.size.width, y: SkinFaceFixture.center.y / SkinFaceFixture.size.height)
        func shrink(_ point: CGPoint) -> CGPoint { CGPoint(x: middle.x + (point.x - middle.x) * 0.05, y: middle.y + (point.y - middle.y) * 0.05) }
        var tiny = SkinFaceFixture.landmarks()
        tiny.box = CGRect(origin: shrink(tiny.box.origin), size: CGSize(width: tiny.box.width * 0.05, height: tiny.box.height * 0.05))
        tiny.contour = tiny.contour.map(shrink)
        tiny.leftEye = tiny.leftEye.map(shrink)
        tiny.rightEye = tiny.rightEye.map(shrink)
        tiny.leftBrow = tiny.leftBrow.map(shrink)
        tiny.rightBrow = tiny.rightBrow.map(shrink)
        tiny.outerLips = tiny.outerLips.map(shrink)
        tiny.innerLips = tiny.innerLips.map(shrink)
        let pass = try #require(smoother(FakeFaceDetector(faces: [tiny])).pass(for: Self.image, value: 100, stream: .main, epoch: 0, time: 0))
        #expect(pass.faces.isEmpty)
    }

    // MARK: - How often it looks

    @Test func theSameMomentIsLookedAtOnce() {
        let detector = FakeFaceDetector(faces: [face])
        let smoother = smoother(detector)
        for _ in 0..<5 { _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 3) }
        #expect(detector.calls == 1, "a paused frame, drawn again and again, is looked at once")
    }

    @Test func itLooksAtMostTwentyTimesASecondOfTheVideo() {
        let detector = FakeFaceDetector(faces: [face])
        let smoother = smoother(detector)
        _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1)
        _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1.02)
        _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1.04)
        #expect(detector.calls == 1)
        _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1.051)
        #expect(detector.calls == 2)
        // A 60 fps video is looked at every third frame, a 30 fps one every other frame.
        for frame in 0..<60 { _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 2 + Double(frame) / 60) }
        #expect(detector.calls <= 2 + 21)
    }

    @Test func aSeekLooksAgainAndShowsTheFaceInFull() throws {
        let detector = FakeFaceDetector(faces: [face])
        let smoother = smoother(detector)
        _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 5)
        let pass = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 2)
        #expect(detector.calls == 2)
        #expect(pass.faces.count == 1 && pass.faces[0].presence == 1)
    }

    // MARK: - Steady

    @Test func aNewStretchOfVideoForgetsTheFacesOfTheLast() throws {
        let detector = FakeFaceDetector(faces: [face])
        let smoother = smoother(detector)
        _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1)
        detector.faces = []
        let sameStretch = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1.034)
        #expect(sameStretch.faces.count == 1, "inside a stretch a missed look is held")
        let nextStretch = smoother.pass(for: Self.image, stream: .main, epoch: 1.03, time: 1.068)
        #expect(nextStretch.faces.isEmpty, "after a cut the old face is not carried over")
    }

    @Test func aFaceTheDetectorMissesOnceIsHeldWithAlmostAllItsStrength() throws {
        let detector = FakeFaceDetector(faces: [face])
        let smoother = smoother(detector)
        _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1)
        detector.faces = []
        let pass = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1.034)
        #expect(pass.faces.count == 1 && pass.faces[0].presence > 0.85)
        let later = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1.034 + Calibration.holdTime + 0.05)
        #expect(later.faces.isEmpty)
    }

    @Test func aFaceThatEntersTheShotFadesInOverAFewFrames() throws {
        let detector = FakeFaceDetector()
        let smoother = smoother(detector)
        _ = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1)
        detector.faces = [face]
        var presences: [Double] = []
        for frame in 1...8 {
            let pass = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 1 + Double(frame) / 30)
            presences.append(pass.faces.first?.presence ?? 0)
        }
        #expect(presences[0] < 0.4)
        #expect(zip(presences, presences.dropFirst()).allSatisfy { $0 <= $1 }, "\(presences)")
        #expect(presences.last == 1)
    }

    @Test func theTwoSidesOfADissolveHaveTheirOwnFaces() throws {
        let detector = FakeFaceDetector(faces: [face])
        let smoother = smoother(detector)
        let main = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 4)
        detector.faces = []
        let blend = smoother.pass(for: Self.image, stream: .blend, epoch: 0, time: 4)
        #expect(main.faces.count == 1 && blend.faces.isEmpty)
        #expect(detector.calls == 2)
        detector.faces = [face]
        let again = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: 4)
        #expect(again.faces.count == 1, "the main side kept its own, untouched by the other")
    }

    @Test func aFaceThatMovesIsFollowedWithoutAJump() throws {
        let detector = FakeFaceDetector(faces: [face])
        let smoother = smoother(detector)
        var regions: [CGFloat] = []
        for frame in 0..<10 {
            detector.faces = [SkinFaceFixture.landmarks(shiftedBy: CGPoint(x: Double(frame) * 6, y: 0))]
            let pass = smoother.pass(for: Self.image, stream: .main, epoch: 0, time: Double(frame) / 30)
            regions.append(try #require(pass.faces.first).region.minX)
        }
        let steps = zip(regions, regions.dropFirst()).map { $1 - $0 }
        #expect(steps.allSatisfy { $0 >= 0 && $0 < 12 }, "\(steps)")
        #expect(regions.last ?? 0 > regions.first ?? 0)
    }

    @Test func twoFacesAreBothPrepared() throws {
        let wide = CGSize(width: 960, height: 640)
        let frame = Self.image.transformed(by: CGAffineTransform(translationX: 480, y: 0))
            .composited(over: Self.image).cropped(to: CGRect(origin: .zero, size: wide))
        let detector = FakeFaceDetector(faces: [
            SkinFaceFixture.landmarks(in: wide), SkinFaceFixture.landmarks(shiftedBy: CGPoint(x: 480, y: 0), in: wide),
        ])
        let pass = try #require(smoother(detector).pass(for: frame, value: 50, stream: .main, epoch: 0, time: 0))
        #expect(pass.faces.count == 2)
        #expect(pass.faces[0].region.minX != pass.faces[1].region.minX)
    }
}
