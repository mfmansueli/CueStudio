//
//  WaveformReader.swift
//  Cue Studio
//

import Accelerate
import AVFoundation

/// The timeline's waveform: how loud a recording is every tenth of a second (RMS, with
/// Accelerate), from 0 (silence) to 1 (as loud as speech gets), on a decibel scale so quiet words
/// still show. Read once per recording, at a low sample rate: it only has to be drawn.
nonisolated enum WaveformReader {
    /// One reading per this many seconds.
    static let interval: TimeInterval = 0.1
    /// Mono, at this rate: plenty for a level, and quick to read.
    static let sampleRate: Double = 8_000
    /// Readings at or under this (dBFS) draw as silence; at or over `loudest`, full height.
    static let quietest: Float = -50
    static let loudest: Float = -6
    /// Silence still draws a sliver, so the strip never looks empty.
    static let floor: Float = 0.04

    /// The levels of the recording's sound, one per `interval`; empty when it has no sound.
    @concurrent
    static func levels(ofVideoAt url: URL) async throws -> [Float] {
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { return [] }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true,
            AVLinearPCMIsNonInterleaved: false,
            AVLinearPCMIsBigEndianKey: false,
            AVNumberOfChannelsKey: 1,
            AVSampleRateKey: sampleRate,
        ])
        let provider = reader.outputProvider(for: output)
        try reader.start()
        let window = Int(sampleRate * interval)
        var samples: [Float] = []
        samples.reserveCapacity(window * 4)
        var levels: [Float] = []
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
            let whole = samples.count / window * window
            if whole > 0 {
                levels += readings(samples[0..<whole], window: window)
                samples.removeFirst(whole)
            }
        }
        if !samples.isEmpty { levels += readings(samples[...], window: samples.count) }
        return levels
    }

    /// One level per `window` samples.
    static func readings(_ samples: ArraySlice<Float>, window: Int) -> [Float] {
        guard window > 0 else { return [] }
        return samples.withContiguousStorageIfAvailable { buffer -> [Float] in
            stride(from: 0, to: buffer.count, by: window).map { offset in
                var rms: Float = 0
                let count = min(window, buffer.count - offset)
                if let base = buffer.baseAddress {
                    vDSP_rmsqv(base + offset, 1, &rms, vDSP_Length(count))
                }
                return level(fromRMS: rms)
            }
        } ?? []
    }

    /// 0 to 1 for an RMS reading, on the decibel scale between `quietest` and `loudest`.
    static func level(fromRMS rms: Float) -> Float {
        guard rms > 0 else { return floor }
        let decibels = 20 * log10(rms)
        let level = (decibels - quietest) / (loudest - quietest)
        return min(1, max(floor, level))
    }
}
