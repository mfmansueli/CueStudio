//
//  SkinTestClip.swift
//  Cue StudioTests
//

import AVFoundation
import CoreImage
import Foundation
import Testing

/// A short portrait test video of one still picture (the drawn face of `SkinFaceFixture`), so a test can follow what the editor's preview and its export
/// do to the same frame.
enum SkinTestClip {
    static let width = 360
    static let height = 640
    private static let framesPerSecond: Int32 = 30

    /// `seconds` of `picture`, 360 × 640, without sound.
    static func make(seconds: Int, picture: CIImage) async throws -> URL {
        try await make(seconds: seconds, width: width, height: height) { _ in picture }
    }

    /// `seconds` of video at 30 fps, `width` × `height`, without sound, each frame (its number) drawn by `frame`: a still picture, or one that moves.
    static func make(seconds: Int, width: Int, height: Int, frame: (Int) -> CIImage) async throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "face-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
            AVVideoCompressionPropertiesKey: [AVVideoAverageBitRateKey: width * height * 8],
        ])
        let receiver = writer.inputPixelBufferReceiver(for: video, pixelBufferAttributes: CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: width, height: height)
        ))
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let pool = try #require(receiver.pixelBufferPool)
        let context = CIContext(options: [.useSoftwareRenderer: false])
        for index in 0..<(seconds * Int(framesPerSecond)) {
            var buffer = try pool.makeMutablePixelBuffer()
            let bytes = try bgra(of: frame(index), width: width, height: height, context: context)
            buffer.accessUnsafeMutableRawPlaneBytes { planes in
                guard let plane = planes.first, let base = plane.bytes.baseAddress else { return }
                for row in 0..<plane.properties.size.height {
                    bytes.withUnsafeBytes { source in
                        _ = memcpy(base.advanced(by: row * plane.properties.bytesPerRow), source.baseAddress!.advanced(by: row * width * 4), width * 4)
                    }
                }
            }
            try await receiver.append(CVReadOnlyPixelBuffer(buffer), with: CMTime(value: CMTimeValue(index), timescale: framesPerSecond))
        }
        receiver.finish()
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(seconds), timescale: 1))
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }

    /// The picture as `width` × `height` BGRA bytes, rows from the top, in sRGB.
    private static func bgra(of picture: CIImage, width: Int, height: Int, context: CIContext) throws -> [UInt8] {
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        context.render(
            picture, toBitmap: &bytes, rowBytes: width * 4, bounds: CGRect(x: 0, y: 0, width: width, height: height), format: .BGRA8, colorSpace: space
        )
        return bytes
    }
}
