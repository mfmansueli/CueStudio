//
//  MovingFootage.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Testing

/// Videos whose motion is known, for the motion analysis, stabilization and tracking: a grain texture that slides (and turns)
/// along a path given frame by frame, as a shaking camera would, and optionally a bright square that moves on its own path (the
/// object a text follows). 30 frames a second, silent, without a track transform.
enum MovingFootage {
    static let framesPerSecond: Int32 = 30

    struct Motion: Sendable {
        /// Where the grain is at a frame, in pixels (right and down positive), and how far it turned (radians, clockwise).
        var background: @Sendable (Int) -> (offset: CGPoint, angle: Double) = { _ in (.zero, 0) }
        /// Where the square's center is at a frame, in pixels from the top left; nil for none.
        var square: (@Sendable (Int) -> CGPoint)?
        var squareSide: CGFloat = 80
    }

    static func make(seconds: Double, width: Int, height: Int, motion: Motion) async throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "moving-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: width, AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: width * height * 6, AVVideoMaxKeyFrameIntervalKey: 30],
        ])
        let size = CGSize(width: width, height: height)
        let receiver = writer.inputPixelBufferReceiver(for: video, pixelBufferAttributes: CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA), size: CVImageSize(width: width, height: height)
        ))
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let pool = try #require(receiver.pixelBufferPool)
        let context = CIContext(options: [.cacheIntermediates: false])
        let noise = try #require(CIFilter.randomGenerator().outputImage)
        let texture = noise.transformed(by: CGAffineTransform(scaleX: 4, y: 4)).applyingGaussianBlur(sigma: 1.2)
        let frames = Int((seconds * Double(framesPerSecond)).rounded())
        for index in 0..<frames {
            let buffer = try pool.makeMutablePixelBuffer()
            let image = frame(index, texture: texture, size: size, motion: motion)
            buffer.withUnsafeBuffer { context.render(image, to: $0) }
            try await receiver.append(CVReadOnlyPixelBuffer(buffer), with: CMTime(value: CMTimeValue(index), timescale: framesPerSecond))
        }
        receiver.finish()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(frames), timescale: framesPerSecond))
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }

    /// One frame in Core Image coordinates (y up): the grain moved, turned about the frame's center, and the square on top.
    private static func frame(_ index: Int, texture: CIImage, size: CGSize, motion: Motion) -> CIImage {
        let (offset, angle) = motion.background(index)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        // Right/down on screen are +x/−y in Core Image; clockwise on screen is a negative Core Image angle.
        let moved = texture
            .transformed(by: CGAffineTransform(translationX: -center.x, y: -center.y)
                .concatenating(CGAffineTransform(rotationAngle: -angle))
                .concatenating(CGAffineTransform(translationX: center.x + offset.x, y: center.y - offset.y)))
        let tinted = moved.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0.5, y: 0, z: 0, w: 0)])
        var image = tinted.cropped(to: CGRect(origin: .zero, size: size))
        if let square = motion.square?(index) {
            let side = motion.squareSide
            let block = CIImage(color: CIColor(red: 1, green: 0.95, blue: 0.2))
                .cropped(to: CGRect(x: square.x - side / 2, y: size.height - square.y - side / 2, width: side, height: side))
            let dot = CIImage(color: CIColor(red: 0.1, green: 0.1, blue: 0.9))
                .cropped(to: CGRect(x: square.x - side / 6, y: size.height - square.y - side / 6, width: side / 3, height: side / 3))
            image = dot.composited(over: block).composited(over: image)
        }
        return image
    }
}
