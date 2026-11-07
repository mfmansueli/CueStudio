//
//  AudioLevelReader.swift
//  Cue Studio
//

import AVFoundation

/// Loudness of an audio file over time, for "Remove silences".
nonisolated enum AudioLevelReader {
    /// One reading every `interval` seconds, in dBFS.
    static func levels(of url: URL, interval: TimeInterval = 0.05) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let framesPerReading = AVAudioFrameCount(max(1, format.sampleRate * interval))
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerReading) else { return [] }
        var levels: [Float] = []
        while file.framePosition < file.length {
            try file.read(into: buffer, frameCount: framesPerReading)
            guard let channel = buffer.floatChannelData?[0], buffer.frameLength > 0 else { break }
            levels.append(level(of: UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))))
        }
        return levels
    }

    /// One reading every `interval` seconds of `samples` (one channel at `sampleRate`), as `levels(of:)` reads a file.
    static func levels(ofSamples samples: [Float], sampleRate: Double, interval: TimeInterval = 0.05) -> [Float] {
        let count = max(1, Int(sampleRate * interval))
        return samples.withUnsafeBufferPointer { all in
            stride(from: 0, to: all.count, by: count).map { start in
                level(of: UnsafeBufferPointer(rebasing: all[start..<min(all.count, start + count)]))
            }
        }
    }

    /// The loudness of a reading's samples: their RMS in dBFS, −120 for digital silence.
    static func level(of samples: UnsafeBufferPointer<Float>) -> Float {
        guard !samples.isEmpty else { return -120 }
        var sum: Float = 0
        for sample in samples {
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(samples.count))
        return rms > 0 ? 20 * log10(rms) : -120
    }

    /// Readings `count` at a time, as one: the mean of their power, in dBFS (what reading every `count` times the interval gives).
    static func combined(_ levels: [Float], every count: Int) -> [Float] {
        guard count > 1 else { return levels }
        return stride(from: 0, to: levels.count, by: count).map { start in
            let slice = levels[start..<min(levels.count, start + count)]
            let power = slice.reduce(0) { $0 + pow(10, $1 / 10) } / Float(slice.count)
            return power > 0 ? 10 * log10(power) : -120
        }
    }
}
