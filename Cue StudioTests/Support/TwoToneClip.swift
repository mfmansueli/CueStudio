//
//  TwoToneClip.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

/// Test pictures for the split screen: a video whose top half is one color and bottom half another (so a test can tell a
/// picture reframed into an area from one merely covered), a photo of one color, and reading the color at any point of an
/// exported frame.
enum TwoToneClip {
    static let red = [220, 40, 40]
    static let blue = [40, 80, 220]
    static let green = [40, 200, 60]
    static let yellow = [230, 210, 40]

    /// A portrait video `seconds` long, `top` over `bottom`; with `loud`, a tone all along.
    static func make(
        seconds: Int, top: [Int], bottom: [Int], loud: Bool = false, width: Int = 360, height: Int = 640
    ) async throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "two-tone-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        let receiver = writer.inputPixelBufferReceiver(for: video, pixelBufferAttributes: CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA), size: CVImageSize(width: width, height: height)
        ))
        var audio: AVAssetWriterInput.SampleBufferReceiver?
        if loud {
            audio = writer.inputReceiver(for: AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: TestClip.sampleRate, AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 96_000,
            ]))
        }
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let frames = seconds * 30
        async let videoFed: Void = feed(receiver, frames: frames, top: top, bottom: bottom)
        async let audioFed: Void = TestClip.feedAudio(audio, frames: frames, loudSeconds: Set(0..<seconds))
        _ = try await (videoFed, audioFed)
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(seconds), timescale: 1))
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }

    /// A JPEG of one color, `width` × `height`.
    static func photo(color: [Int], width: Int, height: Int) throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "photo-\(UUID().uuidString).jpg")
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.setFillColor(red: CGFloat(color[0]) / 255, green: CGFloat(color[1]) / 255, blue: CGFloat(color[2]) / 255, alpha: 1)
        context.fill(CGRect(x: 0, y: 0, width: width, height: height))
        let image = try #require(context.makeImage())
        let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
        CGImageDestinationAddImage(destination, image, nil)
        #expect(CGImageDestinationFinalize(destination))
        return url
    }

    /// The color at `point` (fractions of the frame from the top left) of the frame shown at `time`.
    static func color(at point: CGPoint, time: TimeInterval, in url: URL) async throws -> [Int] {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
        let width = image.width, height = image.height
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let x = min(width - 1, max(0, Int(point.x * CGFloat(width))))
        let y = min(height - 1, max(0, Int(point.y * CGFloat(height))))
        let offset = y * width * 4 + x * 4
        return [Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2])]
    }

    /// Whether two colors are the same within what encoding changes.
    static func same(_ one: [Int], _ other: [Int]) -> Bool {
        zip(one, other).allSatisfy { abs($0 - $1) <= 36 }
    }

    private static func feed(_ receiver: AVAssetWriterInput.PixelBufferReceiver, frames: Int, top: [Int], bottom: [Int]) async throws {
        let pool = try #require(receiver.pixelBufferPool)
        var upper: [UInt8] = [UInt8(top[2]), UInt8(top[1]), UInt8(top[0]), 255]
        var lower: [UInt8] = [UInt8(bottom[2]), UInt8(bottom[1]), UInt8(bottom[0]), 255]
        for frame in 0..<frames {
            var buffer = try pool.makeMutablePixelBuffer()
            buffer.accessUnsafeMutableRawPlaneBytes { planes in
                guard let plane = planes.first, let base = plane.bytes.baseAddress else { return }
                let height = plane.properties.size.height
                let rowLength = plane.properties.size.width * 4
                for row in 0..<height {
                    let start = base.advanced(by: row * plane.properties.bytesPerRow)
                    if row < height / 2 {
                        memset_pattern4(start, &upper, rowLength)
                    } else {
                        memset_pattern4(start, &lower, rowLength)
                    }
                }
            }
            try await receiver.append(CVReadOnlyPixelBuffer(buffer), with: CMTime(value: CMTimeValue(frame), timescale: 30))
        }
        receiver.finish()
    }
}
