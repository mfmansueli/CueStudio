//
//  SkinMaskRasterTests.swift
//  Cue StudioTests
//

import CoreGraphics
import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// The mask of a face's skin: skin where skin is, nothing on the eyes, brows, lips, hair and background.
@Suite("Skin mask")
struct SkinMaskRasterTests {
    private let frame = SkinFaceFixture.size

    /// The weight (0 to 255) of the mask at a point of the frame (pixels, y up); 0 outside its region.
    private func weight(_ mask: SkinMask, at point: CGPoint) -> Int {
        guard mask.region.contains(point) else { return 0 }
        let column = min(mask.width - 1, Int((point.x - mask.region.minX) / mask.region.width * CGFloat(mask.width)))
        let row = min(mask.height - 1, Int((mask.region.maxY - point.y) / mask.region.height * CGFloat(mask.height)))
        return Int(mask.skin[row * mask.width + column])
    }

    private func core(_ mask: SkinMask, at point: CGPoint) -> Bool {
        guard mask.region.contains(point) else { return false }
        let column = min(mask.width - 1, Int((point.x - mask.region.minX) / mask.region.width * CGFloat(mask.width)))
        let row = min(mask.height - 1, Int((mask.region.maxY - point.y) / mask.region.height * CGFloat(mask.height)))
        return mask.core[row * mask.width + column] >= 128
    }

    private func make(_ face: FaceLandmarks? = nil) throws -> SkinMask {
        try #require(SkinMaskRaster.make(face ?? SkinFaceFixture.landmarks(), frame: frame))
    }

    @Test func theCheeksAndTheForeheadAreSkin() throws {
        let mask = try make()
        for point in [CGPoint(x: 150, y: 300), CGPoint(x: 330, y: 300), CGPoint(x: 240, y: 330), CGPoint(x: 240, y: 440)] {
            #expect(weight(mask, at: point) > 200, "\(point): \(weight(mask, at: point))")
        }
    }

    @Test func theEyesTheBrowsAndTheLipsAreNot() throws {
        let mask = try make()
        for eye in SkinFaceFixture.eyeCenters { #expect(weight(mask, at: eye) < 12, "an eye: \(weight(mask, at: eye))") }
        for line in SkinFaceFixture.browLines {
            let middle = CGPoint(x: (line.0.x + line.1.x) / 2, y: (line.0.y + line.1.y) / 2)
            #expect(weight(mask, at: middle) < 15, "a brow: \(weight(mask, at: middle))")
        }
        #expect(weight(mask, at: SkinFaceFixture.lipsCenter) < 20)
    }

    @Test func theHairTheBackgroundAndTheNeckAreNot() throws {
        let mask = try make()
        let cornersOfTheFrame = [CGPoint(x: 5, y: 5), CGPoint(x: 475, y: 635), CGPoint(x: 5, y: 635), CGPoint(x: 475, y: 5)]
        for point in cornersOfTheFrame { #expect(weight(mask, at: point) == 0) }
        // Just outside the jaw, and just past the side of the face.
        #expect(weight(mask, at: CGPoint(x: 240, y: 100)) < 10)
        #expect(weight(mask, at: CGPoint(x: 70, y: 330)) < 10)
        #expect(weight(mask, at: CGPoint(x: 410, y: 330)) < 10)
    }

    @Test func theEdgeOfTheFaceIsSoftAndInsideTheJaw() throws {
        let mask = try make()
        // Walking out from the middle of the cheek to beyond the face, the weight falls without a step.
        let weights = stride(from: 300.0, through: 400, by: 4).map { weight(mask, at: CGPoint(x: $0, y: 300)) }
        for (previous, next) in zip(weights, weights.dropFirst()) { #expect(next <= previous + 2) }
        #expect(zip(weights, weights.dropFirst()).allSatisfy { abs($0 - $1) < 90 }, "no step: it is feathered")
        #expect(weights.first ?? 0 > 200 && weights.last ?? 255 < 10)
    }

    @Test func theCoreIsSkinAwayFromTheFeaturesAndTheBeard() throws {
        let mask = try make()
        #expect(mask.coreCount >= SkinToneAnalyzer.minimumSamples)
        #expect(core(mask, at: CGPoint(x: 150, y: 300)) && core(mask, at: CGPoint(x: 240, y: 440)))
        for eye in SkinFaceFixture.eyeCenters { #expect(!core(mask, at: eye)) }
        #expect(!core(mask, at: SkinFaceFixture.lipsCenter))
        #expect(!core(mask, at: CGPoint(x: 240, y: 160)), "the chin, where a beard grows, is not where the tone is measured")
        #expect(!core(mask, at: CGPoint(x: 5, y: 5)))
    }

    @Test func theRegionIsInsideTheFrameAndCoversTheFace() throws {
        let mask = try make()
        #expect(CGRect(origin: .zero, size: frame).contains(mask.region))
        #expect(mask.region.width == mask.region.integral.width && mask.region.minX == mask.region.integral.minX)
        #expect(mask.region.contains(SkinFaceFixture.center))
        #expect(mask.skin.count == mask.width * mask.height && mask.core.count == mask.skin.count)
        #expect(mask.width == SkinSmoothingCalibration.maskWidth)
    }

    @Test func aFaceAtTheEdgeOfTheFrameIsClippedToIt() throws {
        let face = SkinFaceFixture.landmarks(shiftedBy: CGPoint(x: 150, y: 120))
        let mask = try #require(SkinMaskRaster.make(face, frame: frame))
        #expect(CGRect(origin: .zero, size: frame).contains(mask.region))
    }

    @Test func aTiltedHeadStillHasItsEyesAndLipsTakenOut() throws {
        // Turn every landmark 25° about the middle of the face.
        let angle = 25.0 * .pi / 180
        let center = CGPoint(x: SkinFaceFixture.center.x / frame.width, y: SkinFaceFixture.center.y / frame.height)
        func turn(_ point: CGPoint) -> CGPoint {
            let x = (point.x - center.x) * frame.width, y = (point.y - center.y) * frame.height
            return CGPoint(
                x: center.x + (x * cos(angle) - y * sin(angle)) / frame.width, y: center.y + (x * sin(angle) + y * cos(angle)) / frame.height
            )
        }
        var face = SkinFaceFixture.landmarks()
        face.contour = face.contour.map(turn)
        face.leftEye = face.leftEye.map(turn)
        face.rightEye = face.rightEye.map(turn)
        face.leftBrow = face.leftBrow.map(turn)
        face.rightBrow = face.rightBrow.map(turn)
        face.outerLips = face.outerLips.map(turn)
        face.innerLips = face.innerLips.map(turn)
        let mask = try make(face)
        for eye in SkinFaceFixture.eyeCenters {
            let turned = turn(CGPoint(x: eye.x / frame.width, y: eye.y / frame.height))
            #expect(weight(mask, at: CGPoint(x: turned.x * frame.width, y: turned.y * frame.height)) < 25)
        }
        let lips = turn(CGPoint(x: SkinFaceFixture.lipsCenter.x / frame.width, y: SkinFaceFixture.lipsCenter.y / frame.height))
        #expect(weight(mask, at: CGPoint(x: lips.x * frame.width, y: lips.y * frame.height)) < 25)
        #expect(weight(mask, at: SkinFaceFixture.center) > 200)
    }

    @Test func aFaceWithoutEnoughLandmarksHasNoMask() {
        var face = SkinFaceFixture.landmarks()
        face.leftEye = []
        #expect(SkinMaskRaster.make(face, frame: frame) == nil)
        #expect(SkinMaskRaster.make(SkinFaceFixture.landmarks(), frame: .zero) == nil)
    }

    @Test func theBoxBlurSoftensAnEdgeAndKeepsAFlatField() {
        let flat = [UInt8](repeating: 200, count: 40 * 40)
        #expect(SkinMaskRaster.boxBlurred(flat, width: 40, height: 40, radius: 4) == flat)
        var edge = [UInt8](repeating: 0, count: 40 * 40)
        for row in 0..<40 { for column in 20..<40 { edge[row * 40 + column] = 255 } }
        let soft = SkinMaskRaster.boxBlurred(edge, width: 40, height: 40, radius: 4)
        #expect(soft[20 * 40 + 10] == 0 && soft[20 * 40 + 30] == 255)
        #expect(soft[20 * 40 + 20] > 60 && soft[20 * 40 + 20] < 200)
        #expect(SkinMaskRaster.boxBlurred(edge, width: 40, height: 40, radius: 0) == edge)
    }

    @Test func theMaskAsAnImageCoversItsRegion() throws {
        let mask = try make()
        let image = try #require(mask.image())
        #expect(abs(image.extent.minX - mask.region.minX) < 0.5 && abs(image.extent.width - mask.region.width) < 0.5)
        #expect(abs(image.extent.minY - mask.region.minY) < 0.5 && abs(image.extent.height - mask.region.height) < 0.5)
    }
}
