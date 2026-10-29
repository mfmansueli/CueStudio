//
//  SoundLevelMeter.swift
//  Cue Studio
//

import AVFoundation

/// Readings of a sound's level as it streams by (`AudioLevelReader`'s, without a file to read): one every `interval` seconds,
/// in dBFS, from the first channel. `speechLevel` is what `SpeechLoudness` makes of them.
nonisolated struct SoundLevelMeter {
    private let framesPerReading: Int
    private var sum: Float = 0
    private var count = 0
    private(set) var levels: [Float] = []

    init(sampleRate: Double, interval: TimeInterval = 0.05) {
        framesPerReading = max(1, Int(sampleRate * interval))
    }

    /// The level of the speaking parts so far (the readings over `SpeechLoudness.floor`), nil when nothing spoke.
    var speechLevel: Float? {
        SpeechLoudness.level(of: levels)
    }

    mutating func add(_ buffer: AVAudioPCMBuffer) {
        guard let channel = buffer.floatChannelData?[0] else { return }
        for index in 0..<Int(buffer.frameLength) {
            sum += channel[index] * channel[index]
            count += 1
            if count == framesPerReading {
                let rms = sqrt(sum / Float(count))
                levels.append(rms > 0 ? 20 * log10(rms) : -120)
                sum = 0
                count = 0
            }
        }
    }
}
