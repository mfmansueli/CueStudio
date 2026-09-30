//
//  SpeechFixture.swift
//  Cue StudioTests
//

import AVFAudio
import Foundation
import Testing
@testable import Cue_Studio

/// A recording from `Fixtures/Speech` cut into the buffers a camera would deliver (48 kHz mono
/// 16-bit, 1024 frames, about 21 ms each), with silence or room noise before and after, and when
/// each word of the script ends in it. Latency is measured against these times.
struct SpeechFixture {
    static let sampleRate: Double = 48_000
    static let framesPerBuffer: AVAudioFrameCount = 1024

    let language: CueLanguage
    let script: String
    let buffers: [SendableBuffer]
    /// Seconds from the first buffer to the first audible sample of speech.
    let speechOnset: TimeInterval
    /// Seconds from the first buffer to the end of each script word (`ScriptWords` order).
    let wordEnds: [TimeInterval]
    /// Seconds of lead-in before the recording starts.
    let lead: TimeInterval

    var bufferDuration: TimeInterval { Double(Self.framesPerBuffer) / Self.sampleRate }
    var duration: TimeInterval { Double(buffers.count) * bufferDuration }

    /// An `AVAudioPCMBuffer` handed from the test to the playback thread. Written once here and
    /// only read afterwards.
    final class SendableBuffer: @unchecked Sendable {
        let buffer: AVAudioPCMBuffer
        init(_ buffer: AVAudioPCMBuffer) { self.buffer = buffer }
    }

    private final class BundleToken {}

    /// - Parameters:
    ///   - noise: RMS level in dBFS of white noise under the whole feed (a room), or nil for silence.
    ///   - wordEnds: when each script word ends in the recording, from `timedWords`.
    static func load(
        _ language: CueLanguage, script: String, lead: TimeInterval = 1.5, tail: TimeInterval = 2,
        noise: Float? = nil, timedWords: [TimedWord]
    ) throws -> SpeechFixture {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "speech-\(language.rawValue)", withExtension: "m4a"))
        let speech = try samples(of: url)
        let leadFrames = Int(lead * sampleRate)
        var mono = [Float](repeating: 0, count: leadFrames) + speech + [Float](repeating: 0, count: Int(tail * sampleRate))
        if let noise {
            // Uniform noise has an RMS of amplitude / sqrt(3).
            let amplitude = pow(10, noise / 20) * Float(3).squareRoot()
            var generator = SystemRandomNumberGenerator()
            for index in mono.indices {
                mono[index] += Float.random(in: -amplitude...amplitude, using: &generator)
            }
        }
        let onsetFrame = speech.firstIndex { abs($0) > 0.002 } ?? 0
        let words = ScriptWords(text: script).tokens
        return SpeechFixture(
            language: language, script: script, buffers: try chunks(of: mono),
            speechOnset: lead + Double(onsetFrame) / sampleRate,
            wordEnds: ends(of: words, heard: timedWords).map { lead + $0 },
            lead: lead
        )
    }

    // MARK: - Audio

    /// The recording as 48 kHz mono floats.
    private static func samples(of url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        let source = try #require(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: source)
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false))
        let converter = try #require(AVAudioConverter(from: file.processingFormat, to: format))
        let capacity = AVAudioFrameCount(Double(source.frameLength) * sampleRate / file.processingFormat.sampleRate) + 4096
        let output = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity))
        nonisolated(unsafe) var delivered = false
        var error: NSError?
        converter.convert(to: output, error: &error) { _, status in
            if delivered {
                status.pointee = .endOfStream
                return nil
            }
            delivered = true
            status.pointee = .haveData
            return source
        }
        if let error { throw error }
        let channel = try #require(output.floatChannelData?[0])
        return Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
    }

    /// 16-bit capture-sized buffers.
    private static func chunks(of mono: [Float]) throws -> [SendableBuffer] {
        let format = try #require(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: sampleRate, channels: 1, interleaved: true))
        var result: [SendableBuffer] = []
        var start = 0
        while start < mono.count {
            let count = min(Int(framesPerBuffer), mono.count - start)
            let buffer = try #require(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesPerBuffer))
            buffer.frameLength = AVAudioFrameCount(count)
            let channel = try #require(buffer.int16ChannelData?[0])
            for index in 0..<count {
                channel[index] = Int16(max(-1, min(1, mono[start + index])) * Float(Int16.max))
            }
            result.append(SendableBuffer(buffer))
            start += count
        }
        return result
    }

    // MARK: - Word times

    /// When each script word ends in the recording: the heard word it lines up with, or between
    /// its neighbours' times when recognition missed it.
    private static func ends(of words: [String], heard: [TimedWord]) -> [TimeInterval] {
        let heardKeys = heard.map { WordAlignment.key($0.text) }
        var ends = [TimeInterval?](repeating: nil, count: words.count)
        for match in WordAlignment.matches(words, heardKeys) {
            ends[match.first] = heard[match.second].end
        }
        var result: [TimeInterval] = []
        for index in words.indices {
            if let end = ends[index] {
                result.append(end)
                continue
            }
            let previous = result.last ?? 0
            let nextIndex = ends[(index + 1)...].firstIndex { $0 != nil }
            let next = nextIndex.flatMap { ends[$0] } ?? (heard.last?.end ?? previous)
            let steps = Double((nextIndex ?? words.count) - index + 1)
            result.append(previous + (next - previous) / steps)
        }
        return result
    }
}
