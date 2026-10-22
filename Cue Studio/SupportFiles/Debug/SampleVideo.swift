//
//  SampleVideo.swift
//  Cue Studio
//

#if DEBUG
import AVFoundation
import os
import UIKit

/// Small real videos behind sample takes, so UI tests can play, scrub, trim and cut in Quick
/// edit. Each second has its own color, which makes cuts visible on the timeline. Silent and tiny
/// (144 × 256 at 8 fps), written once at launch with `-uiTestSampleVideo`. Never shipped.
///
/// The frames are written uncompressed (about 70 MB a minute): the iOS 27 Simulator's H.264
/// encoder stalls for good on about one write in four, which froze the launch until the test
/// runner gave up, and it can't encode JPEG. Without an encoder the three sample videos take a
/// couple of seconds, and AVFoundation plays, thumbnails and exports them like any other.
enum SampleVideo {
    nonisolated private static let size = CGSize(width: 144, height: 256)
    nonisolated private static let framesPerSecond: Int32 = 8

    /// Writes a video for each take whose file isn't there yet, as long as the take. One already there is kept only if it plays
    /// as long as the take: the temporary folder outlives launches, and a file a struggling Simulator once left broken was opened
    /// blank by every later test.
    static func writeMissing(for takes: [Take], in repository: TakeRepository) {
        for take in takes {
            let url = repository.videoURL(named: take.fileName)
            if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) {
                guard !plays(url, seconds: take.duration) else { continue }
                try? FileManager.default.removeItem(at: url)
            }
            write(to: url, seconds: take.duration)
        }
    }

    /// Whether `url` is a video about `seconds` long, read off the main actor (blocking, like `write`).
    nonisolated private static func plays(_ url: URL, seconds: TimeInterval) -> Bool {
        let answer = OSAllocatedUnfairLock(initialState: false)
        let checked = DispatchSemaphore(value: 0)
        Task.detached {
            let asset = AVURLAsset(url: url)
            let duration = (try? await asset.load(.duration))?.seconds ?? 0
            let hasVideo = !((try? await asset.loadTracks(withMediaType: .video)) ?? []).isEmpty
            answer.withLock { $0 = hasVideo && abs(duration - seconds) < 0.5 }
            checked.signal()
        }
        checked.wait()
        return answer.withLock { $0 }
    }

    /// Deletes the videos behind `takes`, if an earlier launch wrote them.
    static func remove(for takes: [Take], in repository: TakeRepository) {
        for take in takes {
            let url = repository.videoURL(named: take.fileName)
            try? FileManager.default.removeItem(at: url)
            try? FileManager.default.removeItem(at: partialURL(for: url))
        }
    }

    /// Blocks until the file is written: UI tests open it right after launch. The writing itself
    /// runs off the main actor, since appending waits for the writer to be ready. The frames go to
    /// a separate file that only takes the real name once complete, so a launch the test runner
    /// cut short never leaves a half-written file that later launches would take as done.
    static func write(to url: URL, seconds: TimeInterval) {
        let partial = partialURL(for: url)
        try? FileManager.default.removeItem(at: partial)
        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                try await writeFrames(to: partial, seconds: seconds, size: size, framesPerSecond: framesPerSecond, compressed: false)
                try FileManager.default.moveItem(at: partial, to: url)
            } catch {
                print("SampleVideo: couldn't write \(url.lastPathComponent): \(error)")
                try? FileManager.default.removeItem(at: partial)
            }
            finished.signal()
        }
        finished.wait()
    }

    /// A full-size take (1080 × 1920, 30 fps, HEVC) for export measurements on a device (`-uiTestLongTake`): ten seconds are
    /// encoded and copied end to end without encoding again, so even a long take is written in seconds (a launch that took
    /// longer would be ended by iOS). The Simulator's encoder may stall: device only.
    static func writeLong(to url: URL, seconds: TimeInterval) {
        guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return }
        let partial = partialURL(for: url)
        let chunk = url.deletingPathExtension().appendingPathExtension("chunk").appendingPathExtension("mov")
        [partial, chunk].forEach { try? FileManager.default.removeItem(at: $0) }
        let finished = DispatchSemaphore(value: 0)
        Task.detached {
            do {
                try await writeFrames(to: chunk, seconds: 10, size: CGSize(width: 1080, height: 1920), framesPerSecond: 30, compressed: true)
                try await repeatChunk(chunk, to: partial, seconds: seconds)
                try FileManager.default.moveItem(at: partial, to: url)
            } catch {
                print("SampleVideo: couldn't write \(url.lastPathComponent): \(error)")
                try? FileManager.default.removeItem(at: partial)
            }
            try? FileManager.default.removeItem(at: chunk)
            finished.signal()
        }
        finished.wait()
    }

    /// `chunk` end to end until `seconds`, copied as it is (passthrough).
    nonisolated private static func repeatChunk(_ chunk: URL, to url: URL, seconds: TimeInterval) async throws {
        let asset = AVURLAsset(url: chunk)
        let length = try await asset.load(.duration)
        let composition = AVMutableComposition()
        var cursor = CMTime.zero
        let end = CMTime(seconds: seconds, preferredTimescale: 600)
        while cursor < end {
            let piece = CMTimeMinimum(length, end - cursor)
            try await composition.insertTimeRange(CMTimeRange(start: .zero, duration: piece), of: asset, at: cursor)
            cursor = CMTimeAdd(cursor, piece)
        }
        guard let session = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough) else {
            throw CocoaError(.fileWriteUnknown)
        }
        try await session.export(to: url, as: .mov)
    }

    nonisolated private static func partialURL(for url: URL) -> URL {
        url.deletingPathExtension().appendingPathExtension("partial").appendingPathExtension("mov")
    }

    nonisolated private static func writeFrames(
        to url: URL, seconds: TimeInterval, size: CGSize, framesPerSecond: Int32, compressed: Bool
    ) async throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        // Without output settings (the sample takes) the pixel buffers go into the file as they are, uncompressed.
        let settings: [String: Any]? = compressed
            ? [AVVideoCodecKey: AVVideoCodecType.hevc, AVVideoWidthKey: Int(size.width), AVVideoHeightKey: Int(size.height)]
            : nil
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: settings)
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
        guard writer.status == .completed else { throw writer.error ?? CocoaError(.fileWriteUnknown) }
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
