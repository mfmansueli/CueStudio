//
//  EyeContactAnalyzerTests.swift
//  Cue StudioTests
//

import CoreGraphics
import CoreVideo
import Foundation
import ImageIO
import Testing
@testable import Cue_Studio

/// What the analyzer does around the face mesh (which needs a real face): the order it reads a recording in, the face's crop cut
/// from a frame in any orientation, the mesh turned into two eyes, the eyes' sharpness, the main face and how a track's transform is
/// told to Vision.
@Suite("EyeContactAnalyzer")
struct EyeContactAnalyzerTests {
    @Test func theStretchOnScreenIsReadFirstThenTheRestThenTheStart() {
        let analysis = EyeContactAnalysis(duration: 60, width: 1080, height: 1920, fileStamp: "a")
        let order = EyeContactAnalyzer.order(analysis, focus: 30)
        #expect(order == [TimeSpan(start: 28, end: 45), TimeSpan(start: 45, end: 60), TimeSpan(start: 0, end: 28)])
        #expect(EyeContactAnalyzer.order(analysis, focus: nil) == [TimeSpan(start: 0, end: 60)])
    }

    @Test func whatIsAnalyzedIsNotReadAgain() {
        var analysis = EyeContactAnalysis(duration: 60, width: 1080, height: 1920, fileStamp: "a")
        analysis.add([], over: TimeSpan(start: 28, end: 45))
        #expect(EyeContactAnalyzer.order(analysis, focus: 30) == [TimeSpan(start: 45, end: 60), TimeSpan(start: 0, end: 28)])
    }

    @Test func theRegionTurnsWithTheEyeLineAndMapsTheCropOntoIt() throws {
        // Two "eye corners" on a line tilted 30°, and points around them.
        let angle = 30.0 * .pi / 180
        let center = SIMD2(500.0, 700.0)
        func at(_ x: Double, _ y: Double) -> SIMD2<Double> { center + SIMD2(x * cos(angle) - y * sin(angle), x * sin(angle) + y * cos(angle)) }
        let points = [at(-100, -50), at(100, -50), at(-100, 150), at(100, 150)]
        let region = try #require(FaceRegion.around(points, first: points[0], second: points[1]))
        #expect(abs(region.angle - angle) < 0.000_1)
        #expect(abs(region.side - 200 * FaceRegion.landmarksScale) < 0.001)
        let middle = at(0, 50)
        #expect(abs(region.center.x - middle.x) < 0.001 && abs(region.center.y - middle.y) < 0.001)
        // The crop's middle is the region's centre; its top-left corner is half a side away, turned.
        let mapped = EyeContactAnalyzer.apply(region.cropToUpright, SIMD2(128, 128))
        #expect(abs(mapped.x - region.center.x) < 0.001 && abs(mapped.y - region.center.y) < 0.001)
        let corner = EyeContactAnalyzer.apply(region.cropToUpright, SIMD2(0, 0))
        let expected = center + SIMD2(0, 50).rotated(by: angle) + SIMD2(-region.side / 2, -region.side / 2).rotated(by: angle)
        #expect(abs(corner.x - expected.x) < 0.001 && abs(corner.y - expected.y) < 0.001)
    }

    @Test func theCropCutsTheRegionFromAFrameInAnyOrientation() throws {
        // A frame stored on its side (as the iPhone stores a portrait take): 400 × 300 in the buffer, 300 × 400 upright; a white dot
        // at upright (250, 100) is at buffer (100, 50).
        let transform = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 300, ty: 0)
        let buffer = try #require(Self.frame(width: 400, height: 300))
        // A second dot 20 px to the upright right of the first: it must land to the crop's right (not turned, not mirrored).
        for uprightDot in [CGPoint(x: 250, y: 100), CGPoint(x: 270, y: 100)] {
            let bufferDot = uprightDot.applying(transform.inverted())
            Self.paint(buffer, x: Int(bufferDot.x.rounded()), y: Int(bufferDot.y.rounded()))
        }
        let region = FaceRegion(center: SIMD2(250, 100), side: 64, angle: 0)
        let crop = try #require(FaceCrop().cut(region, from: buffer, uprightFromBuffer: transform))
        // The dot lands in the crop's middle.
        #expect(Self.brightness(crop, x: 128, y: 128) > 100)
        #expect(Self.brightness(crop, x: 128 + 80, y: 128) > 100)
        #expect(Self.brightness(crop, x: 128, y: 128 + 80) < 20 && Self.brightness(crop, x: 128 - 80, y: 128) < 20)
        #expect(Self.brightness(crop, x: 40, y: 40) < 20)
    }

    @Test func aMeshBecomesTwoEyesImageLeftFirst() throws {
        var points = [SIMD2<Double>](repeating: SIMD2(540, 900), count: FaceMesh.count)
        // The mesh's "first" eye drawn on the image's right this time (a mirrored take): it must still come second.
        for (offset, index) in FaceMesh.firstEye.enumerated() { points[index] = SIMD2(700 + Double(offset), 800) }
        for (offset, index) in FaceMesh.secondEye.enumerated() { points[index] = SIMD2(300 + Double(offset), 800) }
        points[FaceMesh.firstIris[0]] = SIMD2(707, 800)
        for index in FaceMesh.firstIris.dropFirst() { points[index] = SIMD2(707, 830) }
        points[FaceMesh.secondIris[0]] = SIMD2(307, 800)
        for index in FaceMesh.secondIris.dropFirst() { points[index] = SIMD2(307, 830) }
        let face = try #require(EyeContactAnalyzer.face(points, size: CGSize(width: 1080, height: 1920), score: 0.9))
        #expect(face.eyes[0].iris.x * 1080 < 400 && face.eyes[1].iris.x * 1080 > 600)
        #expect(abs(face.eyes[0].irisRadius * 1080 - 30) < 0.001)
        #expect(face.eyes.allSatisfy { $0.isComplete })
        #expect(face.confidence == 0.9)
    }

    @Test func aBlurredEyeIsLessSharp() throws {
        let sharp = try #require(Self.frame(width: 256, height: 256)), soft = try #require(Self.frame(width: 256, height: 256))
        for y in stride(from: 100, to: 140, by: 2) { for x in 100..<160 { Self.paint(sharp, x: x, y: y) } }
        let box = CGRect(x: 96, y: 96, width: 70, height: 50)
        #expect(FaceCrop.sharpness(of: sharp, in: box) > 10 * max(1, FaceCrop.sharpness(of: soft, in: box)))
    }

    @Test func theMainFaceIsFollowedElseTheLargest() {
        let small = CGRect(x: 0.1, y: 0.1, width: 0.2, height: 0.2), large = CGRect(x: 0.5, y: 0.5, width: 0.4, height: 0.4)
        #expect(EyeContactAnalyzer.mainFace(in: [small, large], following: nil) == large)
        #expect(EyeContactAnalyzer.mainFace(in: [small, large], following: CGRect(x: 0.11, y: 0.1, width: 0.2, height: 0.2)) == small)
        #expect(EyeContactAnalyzer.mainFace(in: [], following: nil) == nil)
    }

    @Test func eachTurnOfATrackIsToldToVision() {
        let cases: [(CGAffineTransform, CGImagePropertyOrientation)] = [
            (.identity, .up),
            (CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0), .right),
            (CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 1920, ty: 1080), .down),
            (CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 1920), .left),
            (CGAffineTransform(a: -1, b: 0, c: 0, d: 1, tx: 1920, ty: 0), .upMirrored),
            (CGAffineTransform(a: 0, b: 1, c: 1, d: 0, tx: 0, ty: 0), .leftMirrored),
        ]
        for (transform, orientation) in cases {
            #expect(EyeContactAnalyzer.orientation(of: transform) == orientation)
        }
    }

    // MARK: - Frames

    private static func frame(width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let attributes = [kCVPixelBufferIOSurfacePropertiesKey as String: [String: Any]()] as CFDictionary
        CVPixelBufferCreate(nil, width, height, kCVPixelFormatType_32BGRA, attributes, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        if let base = CVPixelBufferGetBaseAddress(buffer) { memset(base, 0, CVPixelBufferGetBytesPerRow(buffer) * height) }
        CVPixelBufferUnlockBaseAddress(buffer, [])
        return buffer
    }

    /// A white 3 × 3 dot centred on (`x`, `y`).
    private static func paint(_ buffer: CVPixelBuffer, x: Int, y: Int) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self) else { return }
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        for dy in -1...1 {
            for dx in -1...1 {
                let px = x + dx, py = y + dy
                guard px >= 0, py >= 0, px < CVPixelBufferGetWidth(buffer), py < CVPixelBufferGetHeight(buffer) else { continue }
                for channel in 0..<4 { base[py * rowBytes + px * 4 + channel] = 255 }
            }
        }
    }

    private static func brightness(_ buffer: CVPixelBuffer, x: Int, y: Int) -> Int {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer)?.assumingMemoryBound(to: UInt8.self) else { return 0 }
        // The brightest of the 5 × 5 around it (resampling spreads the dot).
        var most = 0
        for dy in -2...2 { for dx in -2...2 { most = max(most, Int(base[(y + dy) * CVPixelBufferGetBytesPerRow(buffer) + (x + dx) * 4 + 1])) } }
        return most
    }
}

private extension SIMD2 where Scalar == Double {
    func rotated(by angle: Double) -> SIMD2<Double> { SIMD2(x * cos(angle) - y * sin(angle), x * sin(angle) + y * cos(angle)) }
}
