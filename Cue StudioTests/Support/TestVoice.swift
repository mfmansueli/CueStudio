//
//  TestVoice.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing

/// A made-up voice for sound tests: a 150 Hz tone with its harmonics up to 3 kHz (the band speech lives in), loud where asked,
/// as a 48 kHz mono CAF file (`TestTone`), and what tests read back from sound files.
enum TestVoice {
    /// The harmonic tone, at `amplitude` peak, sounding during `loud` (everywhere when nil).
    static func make(seconds: Double, amplitude: Float = 0.3, loud: [ClosedRange<Double>]? = nil) throws -> URL {
        try TestTone.make(seconds: seconds) { time in
            guard loud?.contains(where: { $0.contains(time) }) ?? true else { return 0 }
            var sample: Float = 0
            for harmonic in 1...20 { sample += Float(sin(2 * .pi * 150 * Double(harmonic) * time)) / Float(harmonic) }
            return amplitude * sample / 2.2
        }
    }

    /// The first channel's samples and the file's rate.
    static func samples(of url: URL) throws -> (samples: [Float], rate: Double) {
        let file = try AVAudioFile(forReading: url)
        let buffer = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channel = try #require(buffer.floatChannelData?[0])
        return (Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength))), file.processingFormat.sampleRate)
    }

    /// Times the sound crosses zero going up, per second: how high it sounds, for a tone.
    static func crossingsPerSecond(_ samples: [Float], rate: Double) -> Double {
        var count = 0
        for index in 1..<samples.count where samples[index - 1] < 0 && samples[index] >= 0 { count += 1 }
        return Double(count) / (Double(samples.count) / rate)
    }

    /// How strong one frequency is in `samples` (Goertzel), in dB: for telling a tone apart under another sound.
    static func level(at frequency: Double, in samples: ArraySlice<Float>, rate: Double) -> Double {
        let coefficient = 2 * cos(2 * .pi * frequency / rate)
        var previous = 0.0, beforePrevious = 0.0
        for sample in samples {
            let current = Double(sample) + coefficient * previous - beforePrevious
            beforePrevious = previous
            previous = current
        }
        let power = previous * previous + beforePrevious * beforePrevious - coefficient * previous * beforePrevious
        return 10 * log10(max(power, 1e-20) / Double(max(1, samples.count * samples.count)))
    }

    /// The samples between two moments.
    static func slice(_ samples: [Float], rate: Double, from start: Double, to end: Double) -> ArraySlice<Float> {
        samples[Int(start * rate)..<min(samples.count, Int(end * rate))]
    }
}
