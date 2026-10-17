//
//  SoundChunkReader.swift
//  Cue Studio
//

import AVFoundation

/// A stretch of a recording's sound handed out a chunk at a time (`chunkSeconds` per buffer, in `format`: its own rate, up to
/// two channels, 32-bit float, one plane per channel), so whoever plays it (`CurveSoundRenderer`) holds a few seconds of it,
/// never the whole stretch. Used by one task at a time.
nonisolated final class SoundChunkReader {
    private let reader: AVAssetReader
    private let provider: AVAssetReaderOutput.Provider<CMReadySampleBuffer<CMSampleBuffer.DynamicContent>>
    private let format: AVAudioFormat
    private let chunkFrames: AVAudioFrameCount
    /// The chunk being filled.
    private var filling: AVAudioPCMBuffer?
    /// Samples (interleaved) read from the file and not yet in a chunk.
    private var waiting: [Float] = []
    private var waitingStart = 0
    private var isFinished = false

    init(asset: AVAsset, track: AVAssetTrack, span: TimeSpan, format: AVAudioFormat, chunkSeconds: Double) throws {
        reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(
            start: CMTime(seconds: span.start, preferredTimescale: 600), end: CMTime(seconds: span.end, preferredTimescale: 600)
        )
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVLinearPCMBitDepthKey: 32, AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false, AVLinearPCMIsBigEndianKey: false, AVNumberOfChannelsKey: format.channelCount,
            AVSampleRateKey: format.sampleRate,
        ])
        provider = reader.outputProvider(for: output)
        self.format = format
        chunkFrames = AVAudioFrameCount(max(1024, format.sampleRate * chunkSeconds))
        try reader.start()
    }

    /// The next chunk; the last one may be shorter; nil once the stretch is all handed out.
    func next() async throws -> AVAudioPCMBuffer? {
        let channels = Int(format.channelCount)
        while !isFinished {
            if waitingStart >= waiting.count {
                waiting.removeAll(keepingCapacity: true)
                waitingStart = 0
                guard try await read() else {
                    isFinished = true
                    break
                }
                continue
            }
            if filling == nil { filling = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: chunkFrames) }
            guard let chunk = filling, let planes = chunk.floatChannelData else { return nil }
            let room = Int(chunk.frameCapacity - chunk.frameLength)
            let frames = min(room, (waiting.count - waitingStart) / channels)
            guard frames > 0 else {
                // Less than a frame left: dropped.
                waitingStart = waiting.count
                continue
            }
            let at = Int(chunk.frameLength)
            for frame in 0..<frames {
                for channel in 0..<channels { planes[channel][at + frame] = waiting[waitingStart + frame * channels + channel] }
            }
            waitingStart += frames * channels
            chunk.frameLength += AVAudioFrameCount(frames)
            if chunk.frameLength == chunk.frameCapacity {
                filling = nil
                return chunk
            }
        }
        // What was left in the chunk being filled.
        defer { filling = nil }
        guard let last = filling, last.frameLength > 0 else { return nil }
        return last
    }

    /// Stops reading the file.
    func cancel() {
        reader.cancelReading()
    }

    /// Reads the next sample buffer's samples into `waiting`; false at the end of the stretch.
    private func read() async throws -> Bool {
        guard let ready = try await provider.next() else { return false }
        ready.withUnsafeSampleBuffer { sample in
            guard let data = CMSampleBufferGetDataBuffer(sample) else { return }
            let count = CMBlockBufferGetDataLength(data) / MemoryLayout<Float>.size
            guard count > 0 else { return }
            waiting = [Float](repeating: 0, count: count)
            waiting.withUnsafeMutableBytes { bytes in
                guard let base = bytes.baseAddress else { return }
                _ = CMBlockBufferCopyDataBytes(data, atOffset: 0, dataLength: count * MemoryLayout<Float>.size, destination: base)
            }
        }
        return true
    }
}
