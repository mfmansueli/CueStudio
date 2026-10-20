//
//  EyeContactRendererTests.swift
//  Cue StudioTests
//

import CoreImage
import CoreVideo
import Foundation
import Testing
@testable import Cue_Studio

/// Eye Contact's drawing on a frame with eyes painted on it: the iris moves up as one piece, nothing outside the eyes' patches
/// changes by a single bit, a recording stored sideways is drawn the same as one stored upright, and nothing to do leaves the frame
/// alone.
@Suite("EyeContactRenderer")
struct EyeContactRendererTests {
    private let face = EyeTestData.face()
    private var frame: EyeContactFrame { EyeContactFrame(eyes: face.eyes, degrees: 12) }

    /// A 1080 × 1920 upright picture (skin, the eyes' whites inside their outlines, a dark iris and pupil) stored with `transform`
    /// (identity: upright; a quarter turn: sideways, as the iPhone stores a portrait take).
    private func painted(transform: CGAffineTransform = .identity) throws -> CVPixelBuffer {
        let size = EyeTestData.size
        let stored = CGRect(origin: .zero, size: size).applying(transform.inverted()).standardized
        var made: CVPixelBuffer?
        CVPixelBufferCreate(nil, Int(stored.width), Int(stored.height), kCVPixelFormatType_32BGRA, nil, &made)
        let buffer = try #require(made)
        let eyes = face.eyes.map { $0.scaled(to: size) }
        let openings = eyes.map { EyePatchFilters.coverage(of: $0.contour, width: Int(size.width), height: Int(size.height)) }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let base = try #require(CVPixelBufferGetBaseAddress(buffer)).assumingMemoryBound(to: UInt8.self)
        let rowBytes = CVPixelBufferGetBytesPerRow(buffer)
        let toBuffer = transform.inverted()
        // The track's transform turns the buffer's rectangle upright; its offset (from the buffer's rectangle) is taken out.
        let upright = CGRect(origin: .zero, size: stored.size).applying(transform)
        for y in 0..<Int(size.height) {
            for x in 0..<Int(size.width) {
                var color: [UInt8] = [150, 170, 210]
                for (eye, opening) in zip(eyes, openings) where opening[y * Int(size.width) + x] > 0.5 {
                    let dx = Double(x) - eye.iris.x, dy = Double(y) - eye.iris.y
                    let r = (dx * dx + dy * dy).squareRoot()
                    color = r < 0.35 * eye.irisRadius ? [15, 15, 15] : r < eye.irisRadius ? [40, 60, 90] : [225, 230, 235]
                }
                let point = CGPoint(x: Double(x) + 0.5 + upright.minX, y: Double(y) + 0.5 + upright.minY).applying(toBuffer)
                let pixel = base + Int(point.y) * rowBytes + Int(point.x) * 4
                pixel[0] = color[0]
                pixel[1] = color[1]
                pixel[2] = color[2]
                pixel[3] = 255
            }
        }
        return buffer
    }

    /// The image's BGRA bytes over the upright frame (top row first), without color management.
    private func upright(_ image: CIImage, transform: CGAffineTransform) -> [UInt8] {
        let size = EyeTestData.size
        let stored = image.extent
        let turned = image.transformed(by: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: stored.height))
            .transformed(by: transform)
        let placed = turned.transformed(by: CGAffineTransform(translationX: -turned.extent.minX, y: -turned.extent.minY))
            .transformed(by: CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: size.height))
        var out = [UInt8](repeating: 0, count: Int(size.width * size.height) * 4)
        let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull(), .cacheIntermediates: false])
        context.render(placed, toBitmap: &out, rowBytes: Int(size.width) * 4, bounds: CGRect(origin: .zero, size: size), format: .BGRA8, colorSpace: nil)
        return out
    }

    /// The mean height (upright rows) of the darkest pixels (the pupil) inside `rect`.
    private func pupilRow(_ bytes: [UInt8], in rect: CGRect) -> Double {
        let width = Int(EyeTestData.size.width)
        var rows: [Double] = []
        for y in Int(rect.minY)..<Int(rect.maxY) {
            for x in Int(rect.minX)..<Int(rect.maxX) where bytes[(y * width + x) * 4] < 25 { rows.append(Double(y)) }
        }
        return rows.isEmpty ? .nan : rows.reduce(0, +) / Double(rows.count)
    }

    @Test func theIrisMovesUpAndNothingOutsideTheEyesChanges() throws {
        let source = try painted()
        let original = CIImage(cvPixelBuffer: source)
        let corrected = EyeContactRenderer().corrected(original, source: source, transform: .identity, frame: frame)
        let before = upright(original, transform: .identity), after = upright(corrected, transform: .identity)
        let eye = face.eyes[0].scaled(to: EyeTestData.size)
        let rect = try #require(EyeContactRenderer.patchRect(eye, within: EyeTestData.size))
        let expected = EyeContactCalibration.eyeballRadius * eye.frame.width * sin(12 * .pi / 180)
        let moved = pupilRow(before, in: rect) - pupilRow(after, in: rect)
        #expect(abs(moved - expected) < 2, "the pupil rose \(moved) px, expected \(expected)")
        // Outside both eyes' patches every byte is the filmed one.
        let rects = face.eyes.compactMap { EyeContactRenderer.patchRect($0.scaled(to: EyeTestData.size), within: EyeTestData.size) }
        let width = Int(EyeTestData.size.width)
        var differing = 0
        for index in stride(from: 0, to: before.count, by: 4) where before[index..<index + 3] != after[index..<index + 3] {
            let point = CGPoint(x: Double((index / 4) % width) + 0.5, y: Double((index / 4) / width) + 0.5)
            if !rects.contains(where: { $0.contains(point) }) { differing += 1 }
        }
        #expect(differing == 0)
    }

    @Test func aSidewaysRecordingIsDrawnTheSameAsAnUprightOne() throws {
        let sideways = CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 1080, ty: 0)
        let flat = try painted(), turned = try painted(transform: sideways)
        let renderer = EyeContactRenderer()
        let a = upright(renderer.corrected(CIImage(cvPixelBuffer: flat), source: flat, transform: .identity, frame: frame), transform: .identity)
        let b = upright(renderer.corrected(CIImage(cvPixelBuffer: turned), source: turned, transform: sideways, frame: frame), transform: sideways)
        var most = 0
        for index in a.indices where index % 4 != 3 { most = max(most, abs(Int(a[index]) - Int(b[index]))) }
        #expect(most <= 2)
    }

    @Test func nothingToDoLeavesTheFrameAlone() throws {
        let source = try painted()
        let renderer = EyeContactRenderer()
        #expect(renderer.patches(source: source, transform: .identity, frame: EyeContactFrame(eyes: face.eyes, degrees: 0), colorSpace: nil).isEmpty)
        #expect(renderer.patches(source: source, transform: .identity, frame: EyeContactFrame(eyes: [], degrees: 12), colorSpace: nil).isEmpty)
        // An eye partly outside the picture isn't drawn.
        var edge = face
        edge.eyes[0].contour = edge.eyes[0].contour.map { SIMD2($0.x - 0.4, $0.y) }
        #expect(renderer.patches(source: source, transform: .identity, frame: EyeContactFrame(eyes: edge.eyes, degrees: 12), colorSpace: nil).count == 1)
    }
}
