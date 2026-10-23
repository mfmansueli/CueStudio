//
//  ShakenFootage.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing
@testable import Cue_Studio

/// A real recording shaken as a hand-held phone would: each frame upright, zoomed in 12% (so the shake never shows an edge) and
/// moved and turned along a path of a few mixed wobbles (about 2% of the frame and half a degree). What Stabilize is measured on
/// when the iPhone's own takes are steady.
enum ShakenFootage {
    static func make(from url: URL, seconds: Double) async throws -> URL {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .video).first)
        let (natural, transform) = try await track.load(.naturalSize, .preferredTransform)
        let rect = CGRect(origin: .zero, size: natural).applying(transform)
        let width = Int(abs(rect.width)) & ~1, height = Int(abs(rect.height)) & ~1
        let output = URL.temporaryDirectory.appending(path: "shaken-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: output, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: width * height * 5],
        ])
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA), size: CVImageSize(width: width, height: height)
        ))
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: seconds, preferredTimescale: 600))
        let provider = reader.outputProvider(for: AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
        ]))
        try reader.start()
        let pool = try #require(receiver.pixelBufferPool)
        let context = CIContext(options: [.cacheIntermediates: false])
        let size = CGSize(width: width, height: height)
        while let ready = try await provider.next() {
            let (image, time): (CIImage?, CMTime) = ready.withUnsafeSampleBuffer { sample in
                guard let pixels = sample.imageBuffer else { return (nil, sample.presentationTimeStamp) }
                var image = CIImage(cvPixelBuffer: pixels)
                    .transformed(by: FramePipeline.uprightTransform(transform, sourceHeight: CGFloat(CVPixelBufferGetHeight(pixels))))
                image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
                return (shaken(image, at: sample.presentationTimeStamp.seconds, size: size), sample.presentationTimeStamp)
            }
            guard let image else { continue }
            let buffer = try pool.makeMutablePixelBuffer()
            buffer.withUnsafeBuffer { context.render(image, to: $0) }
            try await receiver.append(CVReadOnlyPixelBuffer(buffer), with: time)
        }
        receiver.finish()
        writer.endSession(atSourceTime: CMTime(seconds: seconds, preferredTimescale: 600))
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return output
    }

    /// The hand's wobble at `time`: fractions of the frame (right and down) and radians (clockwise).
    static func wobble(at time: TimeInterval) -> (dx: Double, dy: Double, angle: Double) {
        let dx = 0.010 * sin(time * 9.1) + 0.006 * sin(time * 17.3 + 1) + 0.004 * sin(time * 2.3 + 2)
        let dy = 0.009 * sin(time * 7.7 + 0.5) + 0.005 * sin(time * 13.9 + 2) + 0.003 * sin(time * 1.9)
        let angle = 0.006 * sin(time * 6.1 + 1.3) + 0.003 * sin(time * 11.7)
        return (dx, dy, angle)
    }

    private static func shaken(_ image: CIImage, at time: TimeInterval, size: CGSize) -> CIImage {
        let move = wobble(at: time)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let transform = CGAffineTransform(translationX: -center.x, y: -center.y)
            .concatenating(CGAffineTransform(rotationAngle: -move.angle))
            .concatenating(CGAffineTransform(scaleX: 1.12, y: 1.12))
            .concatenating(CGAffineTransform(translationX: center.x + move.dx * size.width, y: center.y - move.dy * size.height))
        return image.clampedToExtent().transformed(by: transform).cropped(to: CGRect(origin: .zero, size: size))
    }
}
