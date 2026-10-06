//
//  UniverseMediaRenderer.swift
//  Cue Studio
//

import AVFoundation
import SwiftUI
import UIKit

/// Renders the universe card on the device (9.2 "Rendered on device"): a 1080 × 1920 PNG with `ImageRenderer`, or a 6 s H.264 video that writes the
/// card's frames, one every 1/20 s, with `AVAssetWriter`.
@MainActor
enum UniverseMediaRenderer {
    enum RenderError: Error { case noImage, writerFailed }

    static let framesPerSecond = 20

    private static var scale: CGFloat { UniverseShareOptions.outputSize.width / UniverseShareOptions.cardSize.width }

    /// The card at `time` (nil: finished) as an image.
    static func image(of card: UniverseShareCard) throws -> UIImage {
        let renderer = ImageRenderer(content: card)
        renderer.scale = scale
        guard let image = renderer.uiImage else { throw RenderError.noImage }
        return image
    }

    static func png(of card: UniverseShareCard) throws -> URL {
        guard let data = try image(of: card).pngData() else { throw RenderError.noImage }
        let url = FileManager.default.temporaryDirectory.appending(path: "My \(card.snapshot.year) universe.png")
        try data.write(to: url, options: .atomic)
        return url
    }

    /// The 6 s video; `progress` hears how far the frames are (0...1).
    static func video(card make: (TimeInterval) -> UniverseShareCard, progress: (Double) -> Void = { _ in }) async throws -> URL {
        let size = UniverseShareOptions.outputSize
        let url = FileManager.default.temporaryDirectory.appending(path: "My universe.mp4")
        try? FileManager.default.removeItem(at: url)
        let writer = try AVAssetWriter(outputURL: url, fileType: .mp4)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height),
        ])
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA), size: CVImageSize(width: Int(size.width), height: Int(size.height))
        )
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let pool = try receiver.pixelBufferPool ?? CVMutablePixelBuffer.Pool(pixelBufferAttributes: attributes)
        let frames = Int(UniverseShareOptions.videoDuration) * framesPerSecond
        for frame in 0..<frames {
            let image = try image(of: make(Double(frame) / Double(framesPerSecond))).cgImage.unwrap(or: RenderError.noImage)
            let frameBuffer = try buffer(from: image, size: size, pool: pool)
            try await receiver.append(frameBuffer, with: CMTime(value: CMTimeValue(frame), timescale: CMTimeScale(framesPerSecond)))
            progress(Double(frame + 1) / Double(frames))
        }
        receiver.finish()
        writer.endSession(atSourceTime: CMTime(seconds: UniverseShareOptions.videoDuration, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? RenderError.writerFailed }
        return url
    }

    /// The image drawn into a BGRA pixel buffer of the pool.
    private static func buffer(from image: CGImage, size: CGSize, pool: CVMutablePixelBuffer.Pool) throws -> CVReadOnlyPixelBuffer {
        var buffer = try pool.makeMutablePixelBuffer()
        buffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard let plane = planes.first, let base = plane.bytes.baseAddress,
                  let context = CGContext(
                      data: base, width: Int(size.width), height: Int(size.height), bitsPerComponent: 8, bytesPerRow: plane.properties.bytesPerRow,
                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                  ) else { return }
            context.draw(image, in: CGRect(origin: .zero, size: size))
        }
        return CVReadOnlyPixelBuffer(buffer)
    }
}

private extension Optional {
    func unwrap(or error: some Error) throws -> Wrapped {
        guard let self else { throw error }
        return self
    }
}
