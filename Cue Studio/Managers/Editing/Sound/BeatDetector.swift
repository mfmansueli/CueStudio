//
//  BeatDetector.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// Reads a sound file the creator brought in from Files and finds its beats (`BeatTracker`), on the iPhone, off the main
/// thread. Up to its first 10 minutes. The beats are kept next to the file (`BeatStore`), so they're found once.
nonisolated enum BeatDetector {
    /// Longest part of a file read.
    static let longest: TimeInterval = 600

    /// The beats of the sound at `url` (seconds into the file); nil when it can't be read or has no pulse.
    @concurrent
    static func beats(inSoundAt url: URL) async -> BeatTracker.Result? {
        guard let samples = try? await monoSamples(of: url) else { return nil }
        return BeatTracker.beats(in: samples)
    }

    /// The file's sound as mono samples at `BeatTracker.sampleRate`.
    static func monoSamples(of url: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = CMTimeRange(start: .zero, duration: CMTime(seconds: longest, preferredTimescale: 600))
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: BeatTracker.sampleRate,
        ])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        var samples: [Float] = []
        while let ready = try await provider.next() {
            try Task.checkCancellation()
            ready.withUnsafeSampleBuffer { sample in
                guard let block = CMSampleBufferGetDataBuffer(sample) else { return }
                let size = MemoryLayout<Float>.size
                let count = CMBlockBufferGetDataLength(block) / size
                guard count > 0 else { return }
                let start = samples.count
                samples.append(contentsOf: repeatElement(0, count: count))
                _ = samples.withUnsafeMutableBytes { bytes in
                    guard let base = bytes.baseAddress else { return kCMBlockBufferBadPointerParameterErr }
                    return CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: count * size, destination: base + start * size)
                }
            }
        }
        return samples
    }
}
