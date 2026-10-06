//
//  FaceLandmarksTests.swift
//  Cue StudioTests
//

import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

@Suite("Face landmarks")
struct FaceLandmarksTests {
    @Test func theDrawnFaceIsUsable() {
        #expect(SkinFaceFixture.landmarks().isUsable)
    }

    @Test func aFaceMissingItsEyesOrLipsOrJawIsNot() {
        var face = SkinFaceFixture.landmarks()
        face.leftEye = []
        #expect(!face.isUsable)
        face = SkinFaceFixture.landmarks()
        face.outerLips = Array(face.outerLips.prefix(2))
        #expect(!face.isUsable)
        face = SkinFaceFixture.landmarks()
        face.contour = Array(face.contour.prefix(4))
        #expect(!face.isUsable)
    }

    @Test func movingTowardAnotherFaceGoesPartWayThere() {
        let from = SkinFaceFixture.landmarks()
        let to = SkinFaceFixture.landmarks(shiftedBy: CGPoint(x: 48, y: 64))
        let half = from.moved(toward: to, rate: 0.5)
        #expect(abs(half.box.minX - (from.box.minX + to.box.minX) / 2) < 0.000_1)
        #expect(abs(half.leftEye[0].y - (from.leftEye[0].y + to.leftEye[0].y) / 2) < 0.000_1)
        #expect(from.moved(toward: to, rate: 0) == from)
        let whole = from.moved(toward: to, rate: 1)
        #expect(abs(whole.box.minX - to.box.minX) < 0.000_1 && abs(whole.center.y - to.center.y) < 0.000_1)
        #expect(from.moved(toward: to, rate: 7) == from.moved(toward: to, rate: 1), "the rate is kept between 0 and 1")
    }

    @Test func outlinesWithAnotherNumberOfPointsAreTakenWhole() {
        let from = SkinFaceFixture.landmarks()
        var to = SkinFaceFixture.landmarks()
        to.outerLips = Array(to.outerLips.prefix(8))
        #expect(from.moved(toward: to, rate: 0.5).outerLips == to.outerLips)
    }
}
