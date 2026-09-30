//
//  TestTone.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing

/// Sound files made up for tests: a tone at a known loudness, silent where asked, as 48 kHz mono
/// float CAF files in the temporary folder.
enum TestTone {
    static let sampleRate: Double = 48_000

    /// A 440 Hz tone `seconds` long at `amplitude` (0 to 1), silent outside `loud` when given.
    static func make(seconds: Double, amplitude: Float = 0.5, loud: [ClosedRange<Double>]? = nil) throws -> URL {
        try make(seconds: seconds) { time in
            guard loud?.contains(where: { $0.contains(time) }) ?? true else { return 0 }
            return amplitude * Float(sin(2 * .pi * 440 * time))
        }
    }

    /// A file whose sample at each moment is `sample(time)`.
    static func make(seconds: Double, _ sample: (Double) -> Float) throws -> URL {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false))
        let url = URL.temporaryDirectory.appending(path: "tone-\(UUID().uuidString.prefix(8)).caf")
        let file = try AVAudioFile(forWriting: url, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        let total = Int(seconds * sampleRate)
        let chunk = 4800
        var written = 0
        while written < total {
            let count = min(chunk, total - written)
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)))
            buffer.frameLength = AVAudioFrameCount(count)
            let channel = try #require(buffer.floatChannelData?[0])
            for index in 0..<count { channel[index] = sample(Double(written + index) / sampleRate) }
            try file.write(from: buffer)
            written += count
        }
        return url
    }

    /// Length of a sound file in seconds.
    static func duration(of url: URL) throws -> Double {
        let file = try AVAudioFile(forReading: url)
        return Double(file.length) / file.processingFormat.sampleRate
    }
}
