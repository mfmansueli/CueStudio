//
//  SoundEffectSynth.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// Makes Cue's sound effects from scratch: oscillators, filtered noise and envelopes, written by Cue (no sample, no recording,
/// no third-party file), the same every time (the noise is seeded). Mono, 48 kHz, peaks at −3 dBFS, at least as long as a clip
/// on the music track (`MusicClip.minimumDuration`). Files are made once into the caches folder and linked into an edit's media
/// when one is added.
nonisolated enum SoundEffectSynth {
    static let sampleRate = 48_000.0
    /// Loudest sample: −3 dBFS, room left for the mix.
    static let peak: Float = 0.708

    /// The effect's samples.
    static func samples(for effect: SoundEffect) -> [Float] {
        var noise = Noise(seed: UInt64(effect.rawValue.unicodeScalars.reduce(7) { $0 &* 31 &+ UInt64($1.value) }))
        let raw: [Float] = switch effect {
        case .whoosh: whoosh(&noise)
        case .pop: pop()
        case .click: click(&noise)
        case .ding: bell(base: 880, length: 1.6)
        case .sparkle: sparkle()
        case .riser: riser(&noise)
        case .boom: boom(&noise)
        case .ping: ping()
        case .typing: typing(&noise)
        case .shutter: shutter(&noise)
        case .buzzer: buzzer()
        }
        // Never shorter than a clip on the music track can be: a short sound is followed by silence.
        let shortest = count(Double(MusicClip.minimumDuration))
        return normalized(raw) + [Float](repeating: 0, count: max(0, shortest - raw.count))
    }

    /// The effect as a file in the caches folder, made the first time it's asked for.
    static func file(for effect: SoundEffect) throws -> URL {
        let folder = URL.cachesDirectory.appending(path: "SoundEffects", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "\(effect.rawValue)-v\(SoundEffect.version).caf")
        if FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) { return url }
        let values = samples(for: effect)
        guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: sampleRate, channels: 1, interleaved: false),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(values.count)),
              let channel = buffer.floatChannelData?[0] else { throw AudioEnhancer.RenderError.noBuffer }
        buffer.frameLength = AVAudioFrameCount(values.count)
        for (index, value) in values.enumerated() { channel[index] = value }
        let partial = url.deletingLastPathComponent().appending(path: UUID().uuidString + ".caf")
        let file = try AVAudioFile(forWriting: partial, settings: format.settings, commonFormat: .pcmFormatFloat32, interleaved: false)
        try file.write(from: buffer)
        do {
            try FileManager.default.moveItem(at: partial, to: url)
        } catch {
            // Made at the same moment elsewhere (the same sound twice): the one already there is the same.
            try? FileManager.default.removeItem(at: partial)
            guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { throw error }
        }
        return url
    }

    // MARK: - Sounds

    private static func count(_ seconds: Double) -> Int { Int(seconds * sampleRate) }

    /// Filtered noise swept up then down through a band, swelling and fading: air going past.
    private static func whoosh(_ noise: inout Noise) -> [Float] {
        let total = count(0.75)
        var band = BandPass()
        return (0..<total).map { index in
            let t = Double(index) / Double(total)
            let frequency = 350 + 2600 * sin(.pi * t)
            band.set(frequency: frequency, q: 1.4)
            let envelope = pow(sin(.pi * t), 1.6)
            return Float(band.process(noise.next()) * envelope)
        }
    }

    /// A drop of pitch in a few milliseconds: a bubble bursting.
    private static func pop() -> [Float] {
        let total = count(0.09)
        var phase = 0.0
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let frequency = 900 * exp(-t * 40) + 180
            phase += 2 * .pi * frequency / sampleRate
            let envelope = min(1, t * 2000) * exp(-t * 45)
            return Float(sin(phase) * envelope)
        }
    }

    /// A short bright tick over a burst of noise.
    private static func click(_ noise: inout Noise) -> [Float] {
        let total = count(0.035)
        var highPass = HighPass(cutoff: 2500)
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let envelope = exp(-t * 260)
            return Float((highPass.process(noise.next()) * 0.7 + sin(2 * .pi * 3200 * t) * 0.5) * envelope)
        }
    }

    /// A struck bell: its partials (inharmonic, as a real bell's) dying away at their own rates.
    private static func bell(base: Double, length: Double) -> [Float] {
        let partials: [(ratio: Double, gain: Double, decay: Double)] = [(1, 1, 2.2), (2.76, 0.5, 3.4), (5.4, 0.25, 5), (8.93, 0.12, 7)]
        return (0..<count(length)).map { index in
            let t = Double(index) / sampleRate
            let attack = min(1, t * 400)
            let value = partials.reduce(0.0) { $0 + sin(2 * .pi * base * $1.ratio * t) * $1.gain * exp(-t * $1.decay) }
            return Float(value * attack)
        }
    }

    /// Three little bells going up, a fifth and an octave apart.
    private static func sparkle() -> [Float] {
        let total = count(1.1)
        var out = [Float](repeating: 0, count: total)
        for (step, frequency) in [1568.0, 2093, 2637].enumerated() {
            let offset = count(0.07 * Double(step))
            let note = bell(base: frequency, length: 0.9)
            for (index, value) in note.enumerated() where offset + index < total { out[offset + index] += value * 0.55 }
        }
        return out
    }

    /// Noise and a tone rising together for a second and a half, growing louder: tension before a reveal.
    private static func riser(_ noise: inout Noise) -> [Float] {
        let total = count(1.6)
        var band = BandPass()
        var phase = 0.0
        return (0..<total).map { index in
            let t = Double(index) / Double(total)
            let frequency = 180 * pow(8, t)
            phase += 2 * .pi * frequency / sampleRate
            band.set(frequency: 400 + 5000 * t * t, q: 0.9)
            let envelope = pow(t, 1.8) * (index > total - count(0.03) ? Double(total - index) / Double(count(0.03)) : 1)
            return Float((band.process(noise.next()) * 0.7 + sin(phase) * 0.35) * envelope)
        }
    }

    /// A deep hit: a low tone falling in pitch, a thump of noise, a long fade.
    private static func boom(_ noise: inout Noise) -> [Float] {
        let total = count(1.4)
        var lowPass = LowPass(cutoff: 180)
        var phase = 0.0
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let frequency = 38 + 52 * exp(-t * 6)
            phase += 2 * .pi * frequency / sampleRate
            let body = sin(phase) * exp(-t * 2.6)
            let thump = lowPass.process(noise.next()) * exp(-t * 18) * 2.5
            let value = (body + thump) * min(1, t * 600)
            return Float(tanh(value * 1.6))
        }
    }

    /// Two quick soft tones, up a fifth.
    private static func ping() -> [Float] {
        let first = bell(base: 1320, length: 0.45)
        let second = bell(base: 1980, length: 0.6)
        let gap = count(0.11)
        var out = [Float](repeating: 0, count: gap + second.count)
        for (index, value) in first.enumerated() where index < out.count { out[index] += value * 0.6 }
        for (index, value) in second.enumerated() { out[gap + index] += value * 0.6 }
        return out
    }

    /// Keys pressed at a typist's uneven pace.
    private static func typing(_ noise: inout Noise) -> [Float] {
        let total = count(0.9)
        var out = [Float](repeating: 0, count: total)
        let key = click(&noise)
        var time = 0.02
        while time < 0.82 {
            let offset = count(time)
            let loudness = Float(0.6 + 0.4 * noise.unit())
            for (index, value) in key.enumerated() where offset + index < total { out[offset + index] += value * loudness }
            time += 0.07 + 0.08 * noise.unit()
        }
        return out
    }

    /// A camera's two blades: a sharp burst, a short pause, another.
    private static func shutter(_ noise: inout Noise) -> [Float] {
        let total = count(0.22)
        var highPass = HighPass(cutoff: 1200)
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let first = exp(-t * 90)
            let second = t > 0.09 ? exp(-(t - 0.09) * 70) * 0.8 : 0
            return Float(highPass.process(noise.next()) * (first + second))
        }
    }

    /// A low, rough buzz: the game-show "wrong".
    private static func buzzer() -> [Float] {
        let total = count(0.55)
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let square = sin(2 * .pi * 150 * t) >= 0 ? 1.0 : -1.0
            let beat = sin(2 * .pi * 157 * t) >= 0 ? 1.0 : -1.0
            let envelope = min(1, t * 200) * min(1, (0.55 - t) * 30)
            return Float((square + beat) * 0.25 * envelope)
        }
    }

    private static func normalized(_ samples: [Float]) -> [Float] {
        let loudest = samples.map(abs).max() ?? 0
        guard loudest > 0 else { return samples }
        let gain = peak / loudest
        return samples.map { $0 * gain }
    }

    // MARK: - Building blocks

    /// White noise from a fixed seed, so a sound is the same every time it's made.
    private struct Noise {
        var state: UInt64

        init(seed: UInt64) { state = seed | 1 }

        /// −1 to 1.
        mutating func next() -> Double { unit() * 2 - 1 }

        /// 0 to 1.
        mutating func unit() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(1 << 53)
        }
    }

    /// A resonant band-pass filter (the RBJ cookbook's biquad), retuned as it plays.
    private struct BandPass {
        private var b0 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
        private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        mutating func set(frequency: Double, q: Double) {
            let omega = 2 * .pi * min(frequency, SoundEffectSynth.sampleRate * 0.45) / SoundEffectSynth.sampleRate
            let alpha = sin(omega) / (2 * q)
            let a0 = 1 + alpha
            b0 = alpha / a0
            b2 = -alpha / a0
            a1 = -2 * cos(omega) / a0
            a2 = (1 - alpha) / a0
        }

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y
        }
    }

    /// One-pole low-pass.
    private struct LowPass {
        private let coefficient: Double
        private var last = 0.0

        init(cutoff: Double) { coefficient = 1 - exp(-2 * .pi * cutoff / SoundEffectSynth.sampleRate) }

        mutating func process(_ x: Double) -> Double {
            last += coefficient * (x - last)
            return last
        }
    }

    /// One-pole high-pass: the input minus its low part.
    private struct HighPass {
        private var low: LowPass

        init(cutoff: Double) { low = LowPass(cutoff: cutoff) }

        mutating func process(_ x: Double) -> Double { x - low.process(x) }
    }
}
