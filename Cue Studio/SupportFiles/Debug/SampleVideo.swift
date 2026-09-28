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
    private static let size = CGSize(width: 144, height: 256)
    private static let framesPerSecond: Int32 = 8

    /// Writes a video for each take whose file isn't there yet, as long as the take.
    static func writeMissing(for takes: [Take], in repository: TakeRepository) {
        for take in takes {
            let url = repository.videoURL(named: take.fileName)
            guard !FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { continue }
            try? write(to: url, seconds: take.duration)
        }
    }

    /// Deletes the videos behind `takes`, if an earlier launch wrote them.
    static func remove(for takes: [Take], in repository: TakeRepository) {
        for take in takes {
            try? FileManager.default.removeItem(at: repository.videoURL(named: take.fileName))
        }
    }

    /// Blocks until the file is written: UI tests open it right after launch.
    static func write(to url: URL, seconds: TimeInterval) throws {
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(size.width),
            AVVideoHeightKey: Int(size.height),
        ])
        input.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(size.width),
            kCVPixelBufferHeightKey as String: Int(size.height),
        ])
        writer.add(input)
        guard writer.startWriting() else { return }
        writer.startSession(atSourceTime: .zero)
        let frames = Int((seconds * Double(framesPerSecond)).rounded(.down))
        for frame in 0..<frames {
            while !input.isReadyForMoreMediaData { Thread.sleep(forTimeInterval: 0.002) }
            guard let buffer = buffer(second: frame / Int(framesPerSecond), pool: adaptor.pixelBufferPool) else { break }
            adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(frame), timescale: framesPerSecond))
        }
        input.markAsFinished()
        writer.endSession(atSourceTime: CMTime(seconds: seconds, preferredTimescale: 600))
        let finished = DispatchSemaphore(value: 0)
        writer.finishWriting { finished.signal() }
        finished.wait()
    }

    private static func buffer(second: Int, pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return nil }
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
        UIColor(hue: CGFloat(second % 12) / 12, saturation: 0.55, brightness: 0.8, alpha: 1)
            .getRed(&red, green: &green, blue: &blue, alpha: nil)
        var pixel: [UInt8] = [UInt8(blue * 255), UInt8(green * 255), UInt8(red * 255), 255]
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let rowLength = CVPixelBufferGetWidth(buffer) * 4
        for row in 0..<CVPixelBufferGetHeight(buffer) {
            memset_pattern4(base.advanced(by: row * bytesPerRow), &pixel, rowLength)
        }
        return buffer
    }
}
#endif
