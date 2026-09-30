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
            var sum: Float = 0
            for index in 0..<Int(buffer.frameLength) {
                sum += channel[index] * channel[index]
            }
            let rms = sqrt(sum / Float(buffer.frameLength))
            levels.append(rms > 0 ? 20 * log10(rms) : -120)
        }
        return levels
    }
}
