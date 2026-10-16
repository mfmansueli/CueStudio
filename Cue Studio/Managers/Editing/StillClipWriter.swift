//
//  StillClipWriter.swift
//  Cue Studio
//

import AVFoundation
import CoreGraphics
import CoreVideo

/// Freeze frame: one frame of a recording, upright and at its size, written as a short silent video into the edit's media, so
/// the montage plays it as a clip of its own (cropped, looked and exported like any other recording). The recording itself is
/// never touched.
nonisolated enum StillClipWriter {
    enum WriteError: Error { case noFrame, cantWrite }

    /// Frames per second of the still: the compositor shows the latest one at any rate.
    static let frameRate: Int32 = 15

    /// Writes `length` seconds of the frame at `time` of the video at `url`. Returns the new file's name in `EditMediaFiles`.
    static func write(frameOf url: URL, at time: TimeInterval, length: TimeInterval) async throws -> String {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        guard let frame = try? await generator.image(at: CMTime(seconds: max(0, time), preferredTimescale: 600)).image else {
            throw WriteError.noFrame
        }
        let (name, destination) = try EditMediaFiles.newFile(pathExtension: "mov")
        do {
            try await write(frame, length: length, to: destination)
        } catch {
            EditMediaFiles.remove([name])
            throw error
        }
        return name
    }

    private static func write(_ frame: CGImage, length: TimeInterval, to destination: URL) async throws {
        // H.264 wants even sides.
        let width = frame.width & ~1, height = frame.height & ~1
        guard width > 0, height > 0 else { throw WriteError.noFrame }
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: width, AVVideoHeightKey: height,
        ])
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA), size: CVImageSize(width: width, height: height)
        )
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let pool = try receiver.pixelBufferPool ?? CVMutablePixelBuffer.Pool(pixelBufferAttributes: attributes)
        var buffer = try pool.makeMutablePixelBuffer()
        buffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard let plane = planes.first, let base = plane.bytes.baseAddress,
                  let context = CGContext(
                      data: base, width: width, height: height, bitsPerComponent: 8, bytesPerRow: plane.properties.bytesPerRow,
                      space: frame.colorSpace ?? CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
                  ) else { return }
            context.draw(frame, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        let still = CVReadOnlyPixelBuffer(buffer)
        let count = max(2, Int((length * Double(frameRate)).rounded(.up)) + 1)
        for index in 0..<count {
            try await receiver.append(still, with: CMTime(value: CMTimeValue(index), timescale: frameRate))
        }
        receiver.finish()
        writer.endSession(atSourceTime: CMTime(seconds: length, preferredTimescale: 600))
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? WriteError.cantWrite }
    }
}
