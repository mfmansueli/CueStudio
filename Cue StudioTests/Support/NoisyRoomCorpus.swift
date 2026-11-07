//
//  NoisyRoomCorpus.swift
//  Cue StudioTests
//

import AVFoundation
import Foundation
import Testing
@testable import Cue_Studio

/// The noisy-room corpus for Clean Up's pauses (D16), made in the test so the repository carries no new audio: per language
/// (pt, en, es), the four FLEURS readings of `Fixtures/Speech/Human` joined by gaps of 1.0, 0.5 and 1.6 s, a weak consonant
/// (120 ms of high-passed noise, 26 dB under the voice: an "s" or "f") at each edge of a gap and a breath (350 ms, 28 dB
/// under) in the long one. Then a background made here, from a fixed seed: a fan (low rumble and a blade tone), traffic (pink
/// noise swelling, two cars passing) or a song (chords, kick, hi-hat), at a signal-to-noise ratio, with the readings' volume
/// changed when a condition says so.
///
/// The ground truth is the clean readings' own envelope, in 10 ms frames: speech where a reading is within 20 dB of its voice
/// (and 10 dB over its own background), with stops under 150 ms inside a word filled and lone clicks left out; the made
/// consonants and breaths are marked as such. The readings have their own rooms (en-US-1 is recorded over a −35 dBFS hum), so
/// "quiet" already isn't silent everywhere.
struct NoisyRoomCorpus: Sendable {
    enum Noise: String, Sendable {
        case none, fan, street, music
    }

    /// What a frame of the clean take is.
    enum Frame: UInt8, Sendable {
        case silence, speech, breath, soft, consonant

        /// A word or a made consonant: what no cut may touch.
        var isWord: Bool { self == .speech || self == .consonant }
    }

    struct Condition: Sendable, CustomTestStringConvertible {
        let name: String
        let noise: Noise
        /// The background this many dB under the speech.
        let snr: Float
        /// Each reading's volume change in dB, in turn.
        let gains: [Float]

        var testDescription: String { name }
    }

    static let conditions: [Condition] = [
        Condition(name: "quiet", noise: .none, snr: 0, gains: [0]),
        Condition(name: "fan 20 dB", noise: .fan, snr: 20, gains: [0]),
        Condition(name: "fan 12 dB", noise: .fan, snr: 12, gains: [0]),
        Condition(name: "fan 6 dB", noise: .fan, snr: 6, gains: [0]),
        Condition(name: "street 15 dB", noise: .street, snr: 15, gains: [0]),
        Condition(name: "street 8 dB", noise: .street, snr: 8, gains: [0]),
        Condition(name: "music 15 dB", noise: .music, snr: 15, gains: [0]),
        Condition(name: "music 8 dB", noise: .music, snr: 8, gains: [0]),
        Condition(name: "soft voice (−12 dB), quiet", noise: .none, snr: 0, gains: [-12]),
        Condition(name: "low speech (−22 dB), quiet", noise: .none, snr: 0, gains: [-22]),
        Condition(name: "low speech (−20 dB), fan 12 dB", noise: .fan, snr: 12, gains: [-20]),
        Condition(name: "volume changes (0/−10/−4/−16 dB), fan 16 dB", noise: .fan, snr: 16, gains: [0, -10, -4, -16]),
    ]

    static let languages = ["pt-BR", "en-US", "es-ES"]
    static let rate = 16_000.0
    /// Samples in a 10 ms frame of the truth.
    static let frame = 160
    /// The pauses the panel lists by default ("Pauses longer than 0.7s").
    static let listedFrom: TimeInterval = 0.7

    /// One language's take in one condition: the mixed sound and the truth.
    struct Take: Sendable {
        var clean: [Float] = []
        var truth: [Frame] = []
        var mixed: [Float] = []
    }

    // MARK: - Making the takes

    /// The condition's take in `language`, the same every run.
    static func take(_ condition: Condition, language index: Int) throws -> Take {
        var random = Generator(seed: 0x9E37_79B9_7F4A_7C15 &+ UInt64(index * 7919 + 1))
        let gaps: [TimeInterval] = [1.0, 0.5, 1.6]
        var take = Take()
        for reading in 1...4 {
            let url = try readingURL(languages[index], reading)
            let gain = pow(10, condition.gains[(reading - 1) % condition.gains.count] / 20)
            var sound = try samples(of: url).map { $0 * gain }
            var truth = activity(of: sound)
            let voice = speechRMS(sound, truth)
            if reading > 1, let first = truth.firstIndex(of: .speech) {
                addConsonant(into: &sound, &truth, atFrame: max(0, first - 12), voice: voice, random: &random)
            }
            if reading < 4, let last = truth.lastIndex(of: .speech) {
                addConsonant(into: &sound, &truth, atFrame: last + 1, voice: voice, random: &random)
            }
            take.append(sound, truth)
            guard reading <= gaps.count else { continue }
            let length = Int(gaps[reading - 1] * rate)
            // Room tone around −66 dBFS.
            var gap = (0..<length).map { _ in random.gaussian() * 0.0005 }
            var gapTruth = [Frame](repeating: .silence, count: length / frame)
            if gaps[reading - 1] > 1.2 { addBreath(into: &gap, &gapTruth, at: length / 2 - 2800, voice: voice, random: &random) }
            take.append(gap, gapTruth)
        }
        take.mixed = mix(take, condition, random: &random)
        return take
    }

    private static func readingURL(_ language: String, _ number: Int) throws -> URL {
        let name = "human-\(language)-\(number)"
        guard let url = Bundle(for: BundleToken.self).url(forResource: name, withExtension: "m4a") else {
            throw CorpusError.missing(name)
        }
        return url
    }

    private static func samples(of url: URL) throws -> [Float] {
        let file = try AVAudioFile(forReading: url)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)) else {
            throw CorpusError.unreadable(url.lastPathComponent)
        }
        try file.read(into: buffer)
        guard file.processingFormat.sampleRate == rate, let channel = buffer.floatChannelData?[0] else {
            throw CorpusError.unreadable(url.lastPathComponent)
        }
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    /// The truth of a clean reading, from its own envelope.
    private static func activity(of sound: [Float]) -> [Frame] {
        let fine = AudioLevelReader.levels(ofSamples: sound, sampleRate: rate, interval: 0.01)
        let readings = AudioLevelReader.levels(ofSamples: sound, sampleRate: rate).filter { $0 > -100 }.sorted()
        let background = readings[readings.count / 10]
        let voiced = fine.filter { $0 > background + 8 }.sorted()
        let voice = voiced.isEmpty ? background + 30 : voiced[voiced.count * 9 / 10]
        let speech = max(voice - 20, background + 10)
        var frames: [Frame] = fine.map { $0 > speech ? .speech : ($0 > background + 5 ? .soft : .silence) }
        // A click (speech-loud for under 50 ms, alone) is a sound, not a word.
        for run in runs(of: .speech, in: frames) where run.count < 5 {
            let near = frames[max(0, run.lowerBound - 15)..<run.lowerBound].contains(.speech)
                || frames[run.upperBound..<min(frames.count, run.upperBound + 15)].contains(.speech)
            if !near { for index in run { frames[index] = .soft } }
        }
        // A quiet gap under 150 ms between loud frames (a stop) is still the word.
        var index = 0
        while index < frames.count {
            guard frames[index] != .speech else { index += 1; continue }
            var end = index
            while end < frames.count, frames[end] != .speech { end += 1 }
            if index > 0, end < frames.count, end - index < 15 { for gap in index..<end { frames[gap] = .speech } }
            index = end
        }
        return frames
    }

    private static func runs(of kind: Frame, in frames: [Frame]) -> [Range<Int>] {
        var result: [Range<Int>] = []
        var index = 0
        while index < frames.count {
            guard frames[index] == kind else { index += 1; continue }
            var end = index
            while end < frames.count, frames[end] == kind { end += 1 }
            result.append(index..<end)
            index = end
        }
        return result
    }

    private static func speechRMS(_ sound: [Float], _ truth: [Frame]) -> Float {
        var sum: Float = 0
        var count = 0
        for (index, kind) in truth.enumerated() where kind == .speech {
            for sample in sound[(index * frame)..<min(sound.count, index * frame + frame)] {
                sum += sample * sample
                count += 1
            }
        }
        return count > 0 ? sqrt(sum / Float(count)) : 0
    }

    /// 120 ms of high-passed noise 26 dB under the voice, fading in and out: an "s" or an "f".
    private static func addConsonant(into sound: inout [Float], _ truth: inout [Frame], atFrame start: Int, voice: Float, random: inout Generator) {
        let first = start * frame
        let length = 12 * frame
        guard first + length <= sound.count else { return }
        var previous: Float = 0
        let amplitude = voice * pow(10, -26 / 20) * 1.12
        for index in 0..<length {
            let white = random.gaussian()
            let envelope = sin(Float.pi * Float(index) / Float(length))
            sound[first + index] += (white - previous) * amplitude * envelope
            previous = white
        }
        for index in start..<min(truth.count, start + 12) { truth[index] = .consonant }
    }

    /// 350 ms of band-limited noise 28 dB under the voice: a breath, which isn't a word.
    private static func addBreath(into sound: inout [Float], _ truth: inout [Frame], at first: Int, voice: Float, random: inout Generator) {
        let length = 5600
        var low: Float = 0
        var previous: Float = 0
        let amplitude = voice * pow(10, -28 / 20) * 2.2
        for index in 0..<length {
            low = 0.7 * low + 0.3 * random.gaussian()
            let envelope = sin(Float.pi * Float(index) / Float(length))
            sound[first + index] += (low - previous) * amplitude * envelope
            previous = low
        }
        for index in (first / frame)..<min(truth.count, (first + length) / frame) { truth[index] = .breath }
    }

    /// The take with the condition's background at its signal-to-noise ratio.
    private static func mix(_ take: Take, _ condition: Condition, random: inout Generator) -> [Float] {
        guard condition.noise != .none else { return take.clean }
        let noise = background(condition.noise, count: take.clean.count, random: &random)
        let noiseRMS = sqrt(noise.reduce(0) { $0 + $1 * $1 } / Float(noise.count))
        let scale = speechRMS(take.clean, take.truth) / noiseRMS * pow(10, -condition.snr / 20)
        return zip(take.clean, noise).map { $0 + $1 * scale }
    }

    private static func background(_ kind: Noise, count: Int, random: inout Generator) -> [Float] {
        var out = [Float](repeating: 0, count: count)
        let seconds = Float(count) / Float(rate)
        var first: Float = 0
        var second: Float = 0
        var third: Float = 0
        for index in 0..<count {
            let time = Float(index) / Float(rate)
            let white = random.gaussian()
            switch kind {
            case .none:
                break
            case .fan:
                // Low rumble and its blade tone, steady.
                first = 0.9 * first + 0.1 * white
                second = 0.6 * second + 0.4 * white
                out[index] = first * 3 + second * 0.6 + 0.25 * sin(2 * .pi * 117 * time)
            case .street:
                // Pink noise that swells and fades, and two cars passing.
                first = 0.99765 * first + white * 0.0990460
                second = 0.96300 * second + white * 0.2965164
                third = 0.57000 * third + white * 1.0526913
                let swell = 3 * sin(2 * .pi * 0.13 * time) + 2 * sin(2 * .pi * 0.31 * time + 1)
                let cars = 9 * exp(-pow((time - 0.3 * seconds) / 1.2, 2)) + 9 * exp(-pow((time - 0.72 * seconds) / 1.5, 2))
                out[index] = (first + second + third + white * 0.1848) * pow(10, (swell + cars) / 20)
            case .music:
                // Chords changing every 2 s, a kick on the beat and a hi-hat between.
                let chord = chords[Int(time / 2) % chords.count]
                var value: Float = chord.reduce(0) { sum, note in
                    sum + 0.3 * sin(2 * .pi * note * time) + 0.12 * sin(4 * .pi * note * time) + 0.05 * sin(6 * .pi * note * time)
                }
                let beat = time.truncatingRemainder(dividingBy: 0.5)
                value += 1.2 * sin(2 * .pi * 55 * beat) * exp(-beat / 0.08)
                let offbeat = (time + 0.25).truncatingRemainder(dividingBy: 0.5)
                value += 0.25 * (white - first) * exp(-offbeat / 0.02)
                first = white
                out[index] = value
            }
        }
        return out
    }

    private static let chords: [[Float]] = [[220, 277, 330], [196, 247, 294], [175, 220, 262], [196, 247, 311]]

    private final class BundleToken {}

    enum CorpusError: Error {
        case missing(String)
        case unreadable(String)
    }

    /// A fixed-seed xorshift: the same noise every run, on every machine.
    struct Generator: Sendable {
        var state: UInt64

        init(seed: UInt64) { state = seed }

        mutating func next() -> UInt64 {
            state ^= state >> 12
            state ^= state << 25
            state ^= state >> 27
            return state &* 2_685_821_657_736_338_717
        }

        mutating func uniform() -> Float { Float(next() >> 40) / Float(1 << 24) }

        /// Roughly normal, from four uniforms.
        mutating func gaussian() -> Float {
            var total: Float = 0
            for _ in 0..<4 { total += uniform() }
            return (total - 2) * 1.732
        }
    }
}

extension NoisyRoomCorpus.Take {
    mutating func append(_ sound: [Float], _ frames: [NoisyRoomCorpus.Frame]) {
        let count = sound.count / NoisyRoomCorpus.frame
        clean += sound.prefix(count * NoisyRoomCorpus.frame)
        truth += frames.prefix(count) + [NoisyRoomCorpus.Frame](repeating: .silence, count: max(0, count - frames.count))
    }
}
