//
//  ReversedSound.swift
//  Cue Studio
//

import AVFoundation
import CoreMedia

/// Reverse's sound: a stretch of a recording's sound read whole, as 32-bit samples, and written back to front.
nonisolated enum ReversedSound {
    /// Frames per buffer handed to the writer.
    static let chunk = 4096

    /// The stretch's samples, interleaved, with its channels (up to two) and rate; nil when it has no sound there.
    static func samples(of asset: AVURLAsset, track: AVAssetTrack, span: TimeSpan) async throws -> (samples: [Float], channels: Int, rate: Double)? {
        let descriptions = try await track.load(.formatDescriptions)
        let basic = descriptions.first.flatMap { CMAudioFormatDescriptionGetStreamBasicDescription($0)?.pointee }
        let rate = basic.map { $0.mSampleRate > 0 ? $0.mSampleRate : 44_100 } ?? 44_100
        let channels = min(2, max(1, Int(basic?.mChannelsPerFrame ?? 1)))
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: span.start, preferredTimescale: 600), end: CMTime(seconds: span.end, preferredTimescale: 600)
        )
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVNumberOfChannelsKey: channels, AVSampleRateKey: rate,
        ])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        var samples: [Float] = []
        while let ready = try await provider.next() {
            ready.withUnsafeSampleBuffer { sample in
                guard let data = CMSampleBufferGetDataBuffer(sample) else { return }
                let count = CMBlockBufferGetDataLength(data) / MemoryLayout<Float>.size
                guard count > 0 else { return }
                let start = samples.count
                samples.append(contentsOf: repeatElement(0, count: count))
                samples.withUnsafeMutableBytes { bytes in
                    guard let base = bytes.baseAddress else { return }
                    _ = CMBlockBufferCopyDataBytes(
                        data, atOffset: 0, dataLength: count * MemoryLayout<Float>.size, destination: base + start * MemoryLayout<Float>.size
                    )
                }
            }
        }
        guard samples.count >= channels else { return nil }
        return (samples, channels, rate)
    }

    /// Appends `samples` (interleaved) back to front, frame by frame, from time zero.
    static func append(_ samples: [Float], channels: Int, rate: Double, to receiver: AVAssetWriterInput.SampleBufferReceiver) async throws {
        let frames = samples.count / channels
        var description = AudioStreamBasicDescription(
            mSampleRate: rate, mFormatID: kAudioFormatLinearPCM, mFormatFlags: kLinearPCMFormatFlagIsFloat | kLinearPCMFormatFlagIsPacked,
            mBytesPerPacket: UInt32(4 * channels), mFramesPerPacket: 1, mBytesPerFrame: UInt32(4 * channels), mChannelsPerFrame: UInt32(channels),
            mBitsPerChannel: 32, mReserved: 0
        )
        var format: CMAudioFormatDescription?
        CMAudioFormatDescriptionCreate(
            allocator: nil, asbd: &description, layoutSize: 0, layout: nil, magicCookieSize: 0, magicCookie: nil, extensions: nil,
            formatDescriptionOut: &format
        )
        guard let format else { return }
        var written = 0
        while written < frames {
            let count = min(chunk, frames - written)
            var reversed = [Float](repeating: 0, count: count * channels)
            for frame in 0..<count {
                let source = frames - 1 - (written + frame)
                for channel in 0..<channels { reversed[frame * channels + channel] = samples[source * channels + channel] }
            }
            let length = reversed.count * MemoryLayout<Float>.size
            var block: CMBlockBuffer?
            CMBlockBufferCreateWithMemoryBlock(
                allocator: nil, memoryBlock: nil, blockLength: length, blockAllocator: nil, customBlockSource: nil, offsetToData: 0,
                dataLength: length, flags: 0, blockBufferOut: &block
            )
            guard let block else { return }
            reversed.withUnsafeBytes { bytes in
                guard let base = bytes.baseAddress else { return }
                _ = CMBlockBufferReplaceDataBytes(with: base, blockBuffer: block, offsetIntoDestination: 0, dataLength: length)
            }
            var sample: CMSampleBuffer?
            CMAudioSampleBufferCreateReadyWithPacketDescriptions(
                allocator: nil, dataBuffer: block, formatDescription: format, sampleCount: count,
                presentationTimeStamp: CMTime(value: CMTimeValue(written), timescale: CMTimeScale(rate)), packetDescriptions: nil,
                sampleBufferOut: &sample
            )
            guard let sample else { return }
            try await receiver.append(CMReadySampleBuffer(unsafeBuffer: sample))
            written += count
        }
    }
}
