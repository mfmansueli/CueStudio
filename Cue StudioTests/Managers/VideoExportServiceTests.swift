//
//  VideoExportServiceTests.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing
@testable import Cue_Studio

/// The exported file is the whole recorded frame, with nothing from the screen on it: the reading
/// line, text window, safe zones and controls are layers over the preview, never in the video.
@MainActor
@Suite("VideoExportService", .serialized)
struct VideoExportServiceTests {
    /// A solid color, as BGRA.
    private static let green: [UInt8] = [90, 160, 40, 255]

    @Test func a9By16ExportIsTheWholeFrameUntouched() async throws {
        let source = try await makeClip()
        defer { try? FileManager.default.removeItem(at: source) }
        let output = try await VideoExportService().export(videoAt: source, options: ExportOptions(aspect: .portrait))
        defer { try? FileManager.default.removeItem(at: output) }

        let image = try await firstFrame(of: output)
        #expect(image.width == 1080 && image.height == 1920)
        try expectSolid(image)
    }

    @Test func a4By5ExportIsTheCenteredCropWithoutOverlays() async throws {
        let source = try await makeClip()
        defer { try? FileManager.default.removeItem(at: source) }
        let output = try await VideoExportService().export(videoAt: source, options: ExportOptions(aspect: .vertical))
        defer { try? FileManager.default.removeItem(at: output) }

        let image = try await firstFrame(of: output)
        #expect(image.width == 1080 && image.height == 1350)
        try expectSolid(image)
    }

    // MARK: - Helpers

    /// A short portrait clip filled with one color, like a recorded take.
    private func makeClip(width: Int = 1080, height: Int = 1920, frames: Int = 6) async throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "clip-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: width, height: height)
        ))
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let pool = try #require(receiver.pixelBufferPool)
        for frame in 0..<frames {
            try await receiver.append(try solidBuffer(pool: pool), with: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        receiver.finish()
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }

    private func solidBuffer(pool: CVMutablePixelBuffer.Pool) throws -> CVReadOnlyPixelBuffer {
        var buffer = try pool.makeMutablePixelBuffer()
        buffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard let plane = planes.first, let base = plane.bytes.baseAddress else { return }
            let pixels = base.assumingMemoryBound(to: UInt8.self)
            for y in 0..<plane.properties.size.height {
                for x in 0..<plane.properties.size.width {
                    let offset = y * plane.properties.bytesPerRow + x * 4
                    for channel in 0..<4 { pixels[offset + channel] = Self.green[channel] }
                }
            }
        }
        return CVReadOnlyPixelBuffer(buffer)
    }

    private func firstFrame(of url: URL) async throws -> CGImage {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .positiveInfinity
        return try await generator.image(at: .zero).image
    }

    /// Corners, edges and center all keep the clip's color: nothing was drawn over the video.
    private func expectSolid(_ image: CGImage) throws {
        let width = image.width, height = image.height
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        // A few pixels in from each edge: compression softens the very border of a crop. The
        // bottom-right point is where the "Made with Cue" badge would sit.
        let points = [
            (8, 8), (width - 9, 8), (8, height - 9), (width - 9, height - 9),
            (width / 2, height / 2), (width / 2, 20), (width / 2, height - 21), (width - 60, height - 80),
        ]
        // RGBA in the context; the clip is BGRA (90, 160, 40) → RGB (40, 160, 90).
        let expected: [Int] = [Int(Self.green[2]), Int(Self.green[1]), Int(Self.green[0])]
        for (x, y) in points {
            let offset = y * width * 4 + x * 4
            let pixel = [Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2])]
            #expect(zip(pixel, expected).allSatisfy { abs($0 - $1) <= 20 }, "pixel at \(x), \(y) is \(pixel)")
        }
    }
}
