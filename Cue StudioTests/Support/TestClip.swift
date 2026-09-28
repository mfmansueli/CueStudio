//
//  TestClip.swift
//  Cue StudioTests
//

import AVFoundation
import CoreGraphics
import Foundation
import Testing

/// Short test videos where every second has its own color and, optionally, its own loudness, so
/// a test can tell exactly which parts of the recording ended up in a player or an export.
enum TestClip {
    /// RGB of each second, in order (then repeating).
    static let colors: [[Int]] = [
        [220, 40, 40], [40, 200, 60], [40, 80, 220], [230, 210, 40], [200, 60, 200], [40, 200, 200],
    ]
    private static let sampleRate = 44_100
    private static let framesPerSecond: Int32 = 30

    /// A portrait clip `seconds` long. With `loudSeconds`, it has a mono sound track: a tone during
    /// those seconds, silence during the others.
    static func make(seconds: Int, loudSeconds: Set<Int>? = nil, width: Int = 360, height: Int = 640) async throws -> URL {
        let url = URL.temporaryDirectory.appending(path: "clip-\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let video = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: width,
            AVVideoHeightKey: height,
        ])
        video.expectsMediaDataInRealTime = false
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: video, sourcePixelBufferAttributes: [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: width,
            kCVPixelBufferHeightKey as String: height,
        ])
        writer.add(video)
        var audio: AVAssetWriterInput?
        if loudSeconds != nil {
            let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                AVFormatIDKey: kAudioFormatMPEG4AAC,
                AVSampleRateKey: sampleRate,
                AVNumberOfChannelsKey: 1,
                AVEncoderBitRateKey: 96_000,
            ])
            input.expectsMediaDataInRealTime = false
            writer.add(input)
            audio = input
        }
        #expect(writer.startWriting())
        writer.startSession(atSourceTime: .zero)

        let frames = seconds * Int(framesPerSecond)
        let samplesPerFrame = sampleRate / Int(framesPerSecond)
        // The writer interleaves the tracks and may hold one back until the other catches up, so
        // each turn feeds whichever input is ready instead of waiting on one of them.
        var nextFrame = 0
        var nextChunk = audio == nil ? frames : 0
        while nextFrame < frames || nextChunk < frames {
            // A failed writer never gets ready again: stop and say why instead of waiting forever.
            if writer.status == .failed { throw writer.error ?? CocoaError(.fileWriteUnknown) }
            var fed = false
            if nextFrame < frames, video.isReadyForMoreMediaData {
                let buffer = try #require(pixelBuffer(color: colors[nextFrame / Int(framesPerSecond) % colors.count], pool: adaptor.pixelBufferPool))
                adaptor.append(buffer, withPresentationTime: CMTime(value: CMTimeValue(nextFrame), timescale: framesPerSecond))
                nextFrame += 1
                // Finished right away, or the writer keeps waiting for more of it before taking
                // the rest of the other track.
                if nextFrame == frames { video.markAsFinished() }
                fed = true
            }
            if let audio, let loudSeconds, nextChunk < frames, audio.isReadyForMoreMediaData {
                let sample = try #require(audioBuffer(start: nextChunk * samplesPerFrame, count: samplesPerFrame, loudSeconds: loudSeconds))
                audio.append(sample)
                nextChunk += 1
                if nextChunk == frames { audio.markAsFinished() }
                fed = true
            }
            if !fed { try await Task.sleep(for: .milliseconds(2)) }
        }
        writer.endSession(atSourceTime: CMTime(value: CMTimeValue(seconds), timescale: 1))
        await writer.finishWriting()
        #expect(writer.status == .completed)
        return url
    }

    // MARK: - Reading back

    /// Which second of the clip the frame at `time` shows, by its color; nil when it matches none.
    static func second(shownAt time: TimeInterval, in url: URL) async throws -> Int? {
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.requestedTimeToleranceBefore = .zero
        generator.requestedTimeToleranceAfter = .zero
        let image = try await generator.image(at: CMTime(seconds: time, preferredTimescale: 600)).image
        let rgb = try centerColor(of: image)
        return colors.firstIndex { zip($0, rgb).allSatisfy { abs($0 - $1) <= 30 } }
    }

    /// Loudness between `start` and `end` in dBFS (about -12 for the tone, far below -40 for
    /// silence).
    static func loudness(of url: URL, from start: TimeInterval, to end: TimeInterval) async throws -> Double {
        let asset = AVURLAsset(url: url)
        let track = try #require(try await asset.loadTracks(withMediaType: .audio).first)
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: CMTime(seconds: start, preferredTimescale: 600), end: CMTime(seconds: end, preferredTimescale: 600))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        reader.add(output)
        #expect(reader.startReading())
        var sum = 0.0
        var count = 0
        while let buffer = output.copyNextSampleBuffer(), let block = CMSampleBufferGetDataBuffer(buffer) {
            let length = CMBlockBufferGetDataLength(block)
            var samples = [Int16](repeating: 0, count: length / 2)
            samples.withUnsafeMutableBytes { bytes in
                _ = CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: length, destination: bytes.baseAddress!)
            }
            for sample in samples {
                let value = Double(sample) / Double(Int16.max)
                sum += value * value
            }
            count += samples.count
        }
        guard count > 0, sum > 0 else { return -160 }
        return 20 * log10((sum / Double(count)).squareRoot())
    }

    // MARK: - Writing

    private static func pixelBuffer(color: [Int], pool: CVPixelBufferPool?) -> CVPixelBuffer? {
        guard let pool else { return nil }
        var buffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(nil, pool, &buffer)
        guard let buffer else { return nil }
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        var bgra: [UInt8] = [UInt8(color[2]), UInt8(color[1]), UInt8(color[0]), 255]
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        let rowLength = CVPixelBufferGetWidth(buffer) * 4
        for row in 0..<CVPixelBufferGetHeight(buffer) {
            memset_pattern4(base.advanced(by: row * bytesPerRow), &bgra, rowLength)
        }
        return buffer
    }

    /// 16-bit mono PCM: a 440 Hz tone in the loud seconds, silence in the others.
    private static func audioBuffer(start: Int, count: Int, loudSeconds: Set<Int>) -> CMSampleBuffer? {
        var description = AudioStreamBasicDescription(
            mSampleRate: Float64(sampleRate), mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kLinearPCMFormatFlagIsSignedInteger | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: 2, mFramesPerPacket: 1, mBytesPerFrame: 2, mChannelsPerFrame: 1,
            mBitsPerChannel: 16, mReserved: 0
        )
        var format: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: nil, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0,
            magicCookie: nil, extensions: nil, formatDescriptionOut: &format
        )
        let samples: [Int16] = (0..<count).map { offset in
            let index = start + offset
            guard loudSeconds.contains(index / sampleRate) else { return 0 }
            return Int16(sin(2 * Double.pi * 440 * Double(index) / Double(sampleRate)) * 12_000)
        }
        let length = count * 2
        var block: CMBlockBuffer?
        CMBlockBufferCreateWithMemoryBlock(
            allocator: nil, memoryBlock: nil, blockLength: length, blockAllocator: nil, customBlockSource: nil,
            offsetToData: 0, dataLength: length, flags: 0, blockBufferOut: &block
        )
        guard let format, let block else { return nil }
        samples.withUnsafeBytes { bytes in
            _ = CMBlockBufferReplaceDataBytes(with: bytes.baseAddress!, blockBuffer: block, offsetIntoDestination: 0, dataLength: length)
        }
        var sample: CMSampleBuffer?
        CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: count,
            presentationTimeStamp: CMTime(value: CMTimeValue(start), timescale: CMTimeScale(sampleRate)),
            packetDescriptions: nil, sampleBufferOut: &sample
        )
        return sample
    }

    private static func centerColor(of image: CGImage) throws -> [Int] {
        let width = image.width, height = image.height
        let context = try #require(CGContext(
            data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let data = try #require(context.data).assumingMemoryBound(to: UInt8.self)
        let offset = (height / 2) * width * 4 + (width / 2) * 4
        return [Int(data[offset]), Int(data[offset + 1]), Int(data[offset + 2])]
    }
}
