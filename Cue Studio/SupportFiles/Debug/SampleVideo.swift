//
//  SampleVideo.swift
//  Cue Studio
//

#if DEBUG
import AVFoundation
import UIKit

/// Small real videos behind sample takes, so UI tests can play, scrub, trim and cut in Quick
/// edit. Each second has its own color, which makes cuts visible on the timeline. Silent and tiny
/// (144 × 256 at 8 fps), written once at launch with `-uiTestSampleVideo`. Never shipped.
enum SampleVideo {
    nonisolated private static let size = CGSize(width: 144, height: 256)
    nonisolated private static let framesPerSecond: Int32 = 8

    /// Writes a video for each take whose file isn't there yet, as long as the take.
    static func writeMissing(for takes: [Take], in repository: TakeRepository) {
        for take in takes {
            let url = repository.videoURL(named: take.fileName)
            guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { continue }
            write(to: url, seconds: take.duration)
        }
    }

    /// Deletes the videos behind `takes`, if an earlier launch wrote them.
    static func remove(for takes: [Take], in repository: TakeRepository) {
        for take in takes {
            try? FileManager.default.removeItem(at: repository.videoURL(named: take.fileName))
        }
    }

    /// Blocks until the file is written: UI tests open it right after launch. The writing itself
    /// runs off the main actor, since appending waits for the writer to be ready.
    static func write(to url: URL, seconds: TimeInterval) {
        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            try? await writeFrames(to: url, seconds: seconds)
            finished.signal()
        }
        finished.wait()
    }

    nonisolated private static func writeFrames(to url: URL, seconds: TimeInterval) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        let attributes = CVPixelBufferCreationAttributes(
            pixelFormatType: CVPixelFormatType(rawValue: kCVPixelFormatType_32BGRA),
            size: CVImageSize(width: Int(size.width), height: Int(size.height))
        )
        let receiver = writer.inputPixelBufferReceiver(for: input, pixelBufferAttributes: attributes)
        try writer.start()
        writer.startSession(atSourceTime: .zero)
        let pool = try receiver.pixelBufferPool ?? CVMutablePixelBuffer.Pool(pixelBufferAttributes: attributes)
        let frames = Int((seconds * Double(framesPerSecond)).rounded(.down))
        for frame in 0..<frames {
            let buffer = try buffer(second: frame / Int(framesPerSecond), pool: pool)
            try await receiver.append(buffer, with: CMTime(value: CMTimeValue(frame), timescale: framesPerSecond))
        }
        receiver.finish()
        writer.endSession(atSourceTime: CMTime(seconds: seconds, preferredTimescale: 600))
        await writer.finishWriting()
    }

    nonisolated private static func buffer(second: Int, pool: CVMutablePixelBuffer.Pool) throws -> CVReadOnlyPixelBuffer {
        var buffer = try pool.makeMutablePixelBuffer()
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(hue: CGFloat(second % 12) / 12, saturation: 0.55, brightness: 0.8, alpha: 1)
            .getRed(&red, green: &green, blue: &blue, alpha: nil)
        var pixel: [UInt8] = [UInt8(blue * 255), UInt8(green * 255), UInt8(red * 255), 255]
        buffer.accessUnsafeMutableRawPlaneBytes { planes in
            guard let plane = planes.first, let base = plane.bytes.baseAddress else { return }
            let rowLength = plane.properties.size.width * 4
            for row in 0..<plane.properties.size.height {
                memset_pattern4(base.advanced(by: row * plane.properties.bytesPerRow), &pixel, rowLength)
            }
        }
        return CVReadOnlyPixelBuffer(buffer)
    }
}
#endif
