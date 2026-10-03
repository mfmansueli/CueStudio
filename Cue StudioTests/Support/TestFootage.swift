//
//  TestFootage.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import Foundation
import Testing

/// Test videos that decode like a take: textured frames that move every frame, in HEVC at about
/// the camera's bit rate with a keyframe every second, and a sound track. For measuring the
/// preview, where `TestClip`'s flat colors would decode far faster than a recording does.
enum TestFootage {
    private static let framesPerSecond: Int32 = 30

    /// A portrait video `seconds` long, `width` × `height`.
    static func make(seconds: Int, width: Int, height: Int) async throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "footage-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.hevc,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [
                // About what the camera writes: ~8 Mbit/s at 1080p, ~33 Mbit/s at 4K.
                AVVideoAverageBitRateKey: width * height * 4,
                AVVideoMaxKeyFrameIntervalKey: Int(framesPerSecond),
                AVVideoExpectedSourceFrameRateKey: Int(framesPerSecond),
            ],
        ])
        let size = CGSize(width: width, height: height)
        let videoReceiver = writer.inputPixelBufferReceiver(for: video, pixelBufferAttributes: CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: width, height: height)
        ))
        let audio = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: TestClip.sampleRate,
            AVNumberOfChannelsKey: 1,
            AVEncoderBitRateKey: 96_000,
        ])
        let audioReceiver = writer.inputReceiver(for: audio)
        try writer.start()
        writer.startSession(atSourceTime: .zero)

        let frames = seconds * Int(framesPerSecond)
        // Both tracks at once, as in `TestClip`: the writer may hold one back until the other
        // catches up.
        async let videoFed: Void = feedVideo(videoReceiver, frames: frames, size: size)
        async let audioFed: Void = TestClip.feedAudio(audioReceiver, frames: frames, loudSeconds: Set(0..<seconds))
        _ = try await (videoFed, audioFed)
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(seconds), timescale: 1))
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }

    private static func feedVideo(_ receiver: AVAssetWriterInput.PixelBufferReceiver, frames: Int, size: CGSize) async throws {
        let pool = try #require(receiver.pixelBufferPool)
        let context = CIContext(options: [.cacheIntermediates: false])
        let texture = try texture()
        for index in 0..<frames {
            let buffer = try pool.makeMutablePixelBuffer()
            let image = try frame(index, texture: texture, size: size)
            buffer.withUnsafeBuffer { context.render(image, to: $0) }
            try await receiver.append(CVReadOnlyPixelBuffer(buffer), with: CMTime(value: CMTimeValue(index), timescale: framesPerSecond))
        }
        receiver.finish()
    }

    /// Soft colored grain, the detail every frame carries.
    private static func texture() throws -> CIImage {
        let noise = try #require(CIFilter.randomGenerator().outputImage)
        return noise.transformed(by: CGAffineTransform(scaleX: 3, y: 3)).applyingGaussianBlur(sigma: 1.5)
    }

    /// The grain sliding a few points a frame under a light that drifts across the picture.
    private static func frame(_ index: Int, texture: CIImage, size: CGSize) throws -> CIImage {
        let seconds = Double(index) / Double(framesPerSecond)
        let light = CIFilter.radialGradient()
        light.center = CGPoint(x: size.width * (0.5 + 0.3 * sin(seconds)), y: size.height * (0.5 + 0.2 * cos(seconds * 0.7)))
        light.radius0 = 0
        light.radius1 = Float(size.width * 0.8)
        light.color0 = CIColor(red: 1, green: 0.85, blue: 0.7)
        light.color1 = CIColor(red: 0.15, green: 0.15, blue: 0.2)
        let blend = CIFilter.multiplyCompositing()
        blend.inputImage = texture.transformed(by: CGAffineTransform(translationX: -CGFloat(index * 3), y: -CGFloat(index * 2)))
        blend.backgroundImage = light.outputImage
        return try #require(blend.outputImage).cropped(to: CGRect(origin: .zero, size: size))
    }
}
