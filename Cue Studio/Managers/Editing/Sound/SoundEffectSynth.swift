//
//  SoundEffectSynth.swift
//  Cue Studio
//

import AVFoundation
import Foundation

/// Makes the sound effects that aren't recordings (`synthesized`: the tonal ones, a tick, a glitch) from scratch: oscillators,
/// filtered noise and envelopes, the same every time (the noise is seeded). Mono, 48 kHz, at least as long as a clip on the music
/// track (`MusicClip.minimumDuration`), and as loud as the recorded ones: each is set to the same short-term loudness
/// (`targetLoudness`, which the offline export levels the recordings to as well), never peaking above −3 dBFS. Files are made
/// once into the caches folder; `SoundEffectFiles` is where the editor asks for any effect's file.
nonisolated enum SoundEffectSynth {
    static let sampleRate = 48_000.0
    /// Loudest sample: −3 dBFS, room left for the mix.
    static let peak: Float = 0.708
    /// How loud every effect is, in LUFS: its loudest 400 ms, K-weighted (ITU-R BS.1770), so a ding is as present as a boom
    /// (most effects stay within a few dB of the level they had when each was set to its peak). A sound whose peak would pass
    /// `peak` at this level (a short click or tick) stops at the peak and is a little quieter.
    static let targetLoudness = -14.0

    /// The effect's samples, at their level.
    static func samples(for effect: SoundEffect) -> [Float] {
        let raw = recipe(for: effect)
        // Never shorter than a clip on the music track can be: a short sound is followed by silence.
        let shortest = count(Double(MusicClip.minimumDuration))
        return leveled(raw + [Float](repeating: 0, count: max(0, shortest - raw.count)))
    }

    /// The effect as its recipe makes it, before its level is set.
    static func recipe(for effect: SoundEffect) -> [Float] {
        var noise = Noise(seed: UInt64(effect.rawValue.unicodeScalars.reduce(7) { $0 &* 31 &+ UInt64($1.value) }))
        return recipes[effect]?(&noise) ?? []
    }

    /// The recipe of each effect Cue synthesizes, handed the effect's own seeded noise (the tonal ones leave it). The other
    /// effects are recordings in the bundle (`SoundEffectFiles`); the tests check that every effect is one or the other.
    private static let recipes: [SoundEffect: @Sendable (inout Noise) -> [Float]] = [
        .swish: swish,
        .drop: drop,
        .glitch: glitch,
        .tick: tick,
        .ding: { _ in bell(base: 880, length: 1.6) },
        .buzzer: { _ in buzzer() },
        .tada: { _ in tada() },
        .sadTrombone: { _ in sadTrombone() },
        .countdown: { _ in countdown() },
        .tickTock: tickTock,
    ]

    /// The effects Cue makes on the device.
    static var synthesized: Set<SoundEffect> { Set(recipes.keys) }

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

    // MARK: - Level

    /// The loudness of the loudest 400 ms of `samples` (a sound shorter than that counts as followed by silence), in LUFS:
    /// K-weighted as ITU-R BS.1770 says for 48 kHz (a high shelf for the head, then a high-pass), mean square, windows a
    /// hundredth of a second apart.
    static func loudness(of samples: [Float]) -> Double {
        var head = Biquad(b0: 1.535_124_859_586_97, b1: -2.691_696_189_406_38, b2: 1.198_392_810_852_85, a1: -1.690_659_293_182_41, a2: 0.732_480_774_215_85)
        var lows = Biquad(b0: 1, b1: -2, b2: 1, a1: -1.990_047_454_833_98, a2: 0.990_072_250_366_21)
        let window = count(0.4)
        let step = count(0.01)
        var sums = [Double](repeating: 0, count: max(window, samples.count) + 1)
        for index in 1..<sums.count {
            let x = index <= samples.count ? Double(samples[index - 1]) : 0
            let weighted = lows.process(head.process(x))
            sums[index] = sums[index - 1] + weighted * weighted
        }
        let last = sums.count - 1 - window
        let starts = Array(stride(from: 0, to: last, by: step)) + [last]
        let loudest = starts.map { (sums[$0 + window] - sums[$0]) / Double(window) }.max() ?? 0
        return loudest > 0 ? -0.691 + 10 * log10(loudest) : -.infinity
    }

    /// Set to `targetLoudness`, or to `peak` if the loudness would take it past that; anything too small to hear is made silence.
    private static func leveled(_ samples: [Float]) -> [Float] {
        let measured = loudness(of: samples)
        let loudest = samples.map(abs).max() ?? 0
        guard measured.isFinite, loudest > 0 else { return samples }
        let gain = min(Float(pow(10, (targetLoudness - measured) / 20)), peak / loudest)
        return samples.map { abs($0 * gain) < 1e-20 ? 0 : $0 * gain }
    }

    // MARK: - Helpers

    private static func count(_ seconds: Double) -> Int { Int(seconds * sampleRate) }

    /// 1 inside, falling to 0 at the first and last sample in straight fades of `attack` and `release` seconds, so a sound
    /// never starts or stops with a click.
    private static func edges(_ index: Int, of total: Int, attack: Double, release: Double) -> Double {
        let fadeIn = attack > 0 ? Double(index) / (attack * sampleRate) : 1
        let fadeOut = release > 0 ? Double(total - 1 - index) / (release * sampleRate) : 1
        return max(0, min(1, fadeIn, fadeOut))
    }

    /// `sound` mixed into `out` from `seconds` on, as far as `out` goes.
    private static func add(_ sound: [Float], into out: inout [Float], at seconds: Double, gain: Double) {
        let offset = count(seconds)
        for (index, value) in sound.enumerated() where offset + index < out.count { out[offset + index] += value * Float(gain) }
    }

    /// `sound` through a soft clipper (its loudest sample taken as 1): the tallest peaks rounded off, as a mix bus would. A
    /// lopsided wave comes out of it a little off centre, so it's brought back with a high-pass well below anything heard.
    private static func saturated(_ sound: [Float], drive: Double) -> [Float] {
        let loudest = Double(sound.map(abs).max() ?? 0)
        guard loudest > 0 else { return sound }
        var centre = Biquad(.highPass, frequency: 20, q: 0.7)
        return sound.map { Float(centre.process(tanh(drive * Double($0) / loudest) / tanh(drive))) }
    }

    // MARK: - Sounds

    /// A short, fast whoosh: noise through a band that leaps up and settles back in a third of a second, loudest early.
    private static func swish(_ noise: inout Noise) -> [Float] {
        let total = count(0.32)
        var band = Biquad(.bandPass, frequency: 600, q: 1.2)
        let air: [Float] = (0..<total).map { index in
            let t = Double(index) / Double(total)
            let shape = sin(.pi * pow(t, 0.6))
            band.tune(.bandPass, frequency: 450 + 2200 * shape, q: 1.2)
            return Float(band.process(noise.next()) * pow(shape, 1.4))
        }
        return saturated(air, drive: 1.5)
    }

    /// The floor falling away: a low tone sliding from 160 Hz down to 34 Hz over a rumble, with its octave and warmed so it
    /// carries on a phone's speaker, fading as it falls.
    private static func drop(_ noise: inout Noise) -> [Float] {
        let total = count(1.5)
        var tone = Oscillator()
        var rumble = Biquad(.lowPass, frequency: 400, q: 0.7)
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let frequency = 34 + 126 * exp(-t * 2.4)
            rumble.tune(.lowPass, frequency: 90 + 400 * exp(-t * 3), q: 0.7)
            let phase = 2 * .pi * tone.step(frequency).phase
            let body = sin(phase) + 0.35 * sin(2 * phase) + rumble.process(noise.next()) * 0.6 * exp(-t * 4)
            let envelope = edges(index, of: total, attack: 0.006, release: 0.06) * exp(-t * 2)
            return Float(tanh(body * envelope * 3) / tanh(3))
        }
    }

    /// Stuttered digital chops: a buzzy tone, crushed noise and a ring-modulated drone cut into slices, some repeated, ending on
    /// a tone falling like a tape stopping. Each slice fades in and out over a millisecond and a half.
    private static func glitch(_ noise: inout Noise) -> [Float] {
        let length = count(0.2)
        var high = Oscillator(), low = Oscillator(), ring = Oscillator(), fall = Oscillator()
        var crush = Biquad(.lowPass, frequency: 6000, q: 0.7), dull = Biquad(.lowPass, frequency: 3000, q: 0.7)
        var tape = Biquad(.lowPass, frequency: 4500, q: 0.7)
        var held = 0.0
        var buzz: [Double] = [], buzzHigh: [Double] = [], crushed: [Double] = [], drone: [Double] = [], falling: [Double] = []
        for index in 0..<length {
            let t = Double(index) / sampleRate
            buzz.append(low.pulse(740, width: 0.3) * 0.5)
            buzzHigh.append(high.pulse(1480, width: 0.3) * 0.4)
            if index % 20 == 0 { held = noise.next() }
            crushed.append(crush.process(held) * 0.9)
            drone.append(dull.process(ring.pulse(196) * sin(2 * .pi * 1100 * t)) * 0.6)
            let slowing = 120 + 780 * exp(-t * 18)
            tape.tune(.lowPass, frequency: slowing * 5, q: 0.7)
            falling.append(tape.process(fall.pulse(slowing)) * (1 - t / 0.2) * 0.55)
        }
        // What plays (none: a gap), from where in it, for how long, how many times in a row.
        let chops: [(source: [Double], from: Double, seconds: Double, repeats: Int)] = [
            (buzz, 0, 0.035, 3),
            (crushed, 0, 0.05, 1),
            ([], 0, 0.02, 1),
            (drone, 0, 0.04, 2),
            (buzzHigh, 0.01, 0.02, 4),
            (crushed, 0.05, 0.03, 1),
            ([], 0, 0.015, 1),
            (falling, 0, 0.18, 1),
        ]
        var out: [Float] = []
        for chop in chops {
            let size = count(chop.seconds)
            let slice = (0..<size).map { index in
                let value = chop.source.isEmpty ? 0 : chop.source[count(chop.from) + index]
                return Float(value * edges(index, of: size, attack: 0.0015, release: 0.0015))
            }
            for _ in 0..<chop.repeats { out += slice }
        }
        var smooth = Biquad(.lowPass, frequency: 8000, q: 0.7)
        return out.map { Float(smooth.process(Double($0))) }
    }

    /// A soft wooden tick: a small block of wood struck once.
    private static func tick(_ noise: inout Noise) -> [Float] {
        knock(&noise, base: 950, length: 0.12, partials: [(1, 1, 55), (2.71, 0.3, 95), (4.6, 0.08, 150)])
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

    /// "Ta-da!": a bright, brassy C major chord climbing C–E–G–C in quick steps and holding, mellowing as it rings.
    private static func tada() -> [Float] {
        let total = count(1.4)
        var out = [Float](repeating: 0, count: total)
        for (step, frequency) in [523.25, 659.25, 783.99, 1046.5].enumerated() {
            let start = 0.06 * Double(step)
            add(brass(frequency: frequency, length: 1.4 - start), into: &out, at: start, gain: 0.3)
        }
        return saturated(out, drive: 1.5)
    }

    /// Two slightly detuned saws through a low-pass that opens wide as the note starts, then closes to a warm tone: a bright
    /// brass section's note, with a little vibrato once it holds.
    private static func brass(frequency: Double, length: Double) -> [Float] {
        let total = count(length)
        var left = Oscillator(), right = Oscillator(phase: 0.37)
        var tone = Biquad(.lowPass, frequency: 4000, q: 0.8)
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let vibrato = 1 + 0.004 * sin(2 * .pi * 5.5 * t) * min(1, max(0, t - 0.3) * 3)
            tone.tune(.lowPass, frequency: min(4500, frequency * (1.6 + 3.5 * exp(-t * 7))), q: 0.8)
            let value = tone.process(left.saw(frequency * 0.997 * vibrato) + right.saw(frequency * 1.003 * vibrato))
            let envelope = (0.55 + 0.45 * exp(-t * 6)) * exp(-t * 1.1) * edges(index, of: total, attack: 0.012, release: 0.2)
            return Float(value * envelope)
        }
    }

    /// The sad trombone: four notes stepping down a semitone at a time, each a muted "wah", the last one long and wobbling.
    private static func sadTrombone() -> [Float] {
        let total = count(2.15)
        var out = [Float](repeating: 0, count: total)
        for (step, frequency) in [293.66, 277.18, 261.63, 246.94].enumerated() {
            let last = step == 3
            add(trombone(frequency: frequency, length: last ? 0.85 : 0.36, wobbles: last), into: &out, at: 0.42 * Double(step), gain: 0.8)
        }
        return saturated(out, drive: 1.5)
    }

    /// One muted trombone note: a saw sliding up into its pitch, through a resonant low-pass that opens and closes ("wah");
    /// a wobbling one shakes in pitch and in mute and sags at the end.
    private static func trombone(frequency: Double, length: Double, wobbles: Bool) -> [Float] {
        let total = count(length)
        var tone = Oscillator()
        var mute = Biquad(.lowPass, frequency: 400, q: 3)
        var floor = Biquad(.highPass, frequency: 40, q: 0.7)
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let progress = t / length
            let wobble = wobbles ? sin(2 * .pi * 5 * t) * min(1, t / 0.2) : 0
            let pitch = frequency * (1 - 0.03 * exp(-t / 0.02)) * (1 + 0.012 * wobble) * (wobbles ? 1 - 0.04 * pow(progress, 3) : 1)
            let opening = wobbles ? (0.55 + 0.45 * wobble) * (1 - 0.6 * progress) : pow(sin(.pi * min(1, progress * 1.2)), 1.5)
            mute.tune(.lowPass, frequency: 350 + 1500 * opening, q: 3)
            let envelope = (0.6 + 0.4 * opening) * edges(index, of: total, attack: 0.02, release: 0.05)
            return Float(floor.process(mute.process(tone.saw(pitch))) * envelope)
        }
    }

    /// Three short beeps and a long one an octave up: ready, set, go.
    private static func countdown() -> [Float] {
        let total = count(1.85)
        var out = [Float](repeating: 0, count: total)
        for step in 0..<3 { add(beep(frequency: 880, length: 0.11), into: &out, at: 0.42 * Double(step), gain: 1) }
        add(beep(frequency: 1760, length: 0.58), into: &out, at: 1.26, gain: 1)
        return out
    }

    /// A clean electronic beep with a little body (its second and third harmonics).
    private static func beep(frequency: Double, length: Double) -> [Float] {
        let total = count(length)
        var tone = Oscillator()
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let phase = 2 * .pi * tone.step(frequency).phase
            let value = sin(phase) + 0.25 * sin(2 * phase) + 0.08 * sin(3 * phase)
            return Float(value * exp(-t * 0.8) * edges(index, of: total, attack: 0.004, release: 0.012))
        }
    }

    /// A clock: tick, tock, tick, tock, a little over three a second, the tock lower.
    private static func tickTock(_ noise: inout Noise) -> [Float] {
        let total = count(1.2)
        var out = [Float](repeating: 0, count: total)
        let clock: [(ratio: Double, gain: Double, decay: Double)] = [(1, 1, 140), (1.93, 0.5, 200), (3.1, 0.2, 260)]
        for step in 0..<4 {
            let isTick = step.isMultiple(of: 2)
            add(knock(&noise, base: isTick ? 1700 : 1250, length: 0.06, partials: clock), into: &out, at: 0.3 * Double(step), gain: 1)
        }
        return out
    }

    /// Something small and hard struck: a few partials ringing at `base` times their ratio, each dying at its own rate, and the
    /// strike's own short burst of noise.
    private static func knock(_ noise: inout Noise, base: Double, length: Double, partials: [(ratio: Double, gain: Double, decay: Double)]) -> [Float] {
        let total = count(length)
        var strike = Biquad(.lowPass, frequency: 3000, q: 0.7)
        return (0..<total).map { index in
            let t = Double(index) / sampleRate
            let ring = partials.reduce(0.0) { $0 + sin(2 * .pi * base * $1.ratio * t) * $1.gain * exp(-t * $1.decay) }
            let burst = strike.process(noise.next()) * exp(-t * 900) * 0.6
            return Float((ring + burst) * edges(index, of: total, attack: 0.0004, release: 0.01))
        }
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

    /// An oscillator: where its wave is, stepped on sample by sample at any (changing) frequency. Its saw and pulse are
    /// band-limited with polyBLEP (each jump smoothed over a sample either side), so high notes don't alias.
    private struct Oscillator {
        private var phase: Double

        init(phase: Double = 0) { self.phase = phase }

        /// Where the wave is (0 to 1) and how far it moves per sample, then a step on.
        mutating func step(_ frequency: Double) -> (phase: Double, increment: Double) {
            let now = phase
            let increment = frequency / SoundEffectSynth.sampleRate
            phase += increment
            phase -= phase.rounded(.down)
            return (now, increment)
        }

        mutating func saw(_ frequency: Double) -> Double {
            let (phase, increment) = step(frequency)
            return 2 * phase - 1 - Self.blep(phase, increment)
        }

        /// High for `width` of each cycle, low for the rest, centred on zero.
        mutating func pulse(_ frequency: Double, width: Double = 0.5) -> Double {
            let (phase, increment) = step(frequency)
            var value = phase < width ? 1.0 : -1.0
            value += Self.blep(phase, increment)
            value -= Self.blep((phase - width + 1).truncatingRemainder(dividingBy: 1), increment)
            return value - (2 * width - 1)
        }

        /// The polyBLEP correction for a jump at phase 0.
        private static func blep(_ phase: Double, _ increment: Double) -> Double {
            if phase < increment {
                let x = phase / increment
                return x + x - x * x - 1
            }
            if phase > 1 - increment {
                let x = (phase - 1) / increment
                return x * x + x + x + 1
            }
            return 0
        }
    }

    private enum FilterShape { case lowPass, highPass, bandPass }

    /// A biquad filter (the RBJ cookbook's low-, high- and band-pass, retunable as it plays), or one given its coefficients.
    private struct Biquad {
        private var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
        private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

        init(_ shape: FilterShape, frequency: Double, q: Double) { tune(shape, frequency: frequency, q: q) }

        init(b0: Double, b1: Double, b2: Double, a1: Double, a2: Double) {
            (self.b0, self.b1, self.b2, self.a1, self.a2) = (b0, b1, b2, a1, a2)
        }

        mutating func tune(_ shape: FilterShape, frequency: Double, q: Double) {
            let omega = 2 * .pi * min(frequency, SoundEffectSynth.sampleRate * 0.45) / SoundEffectSynth.sampleRate
            let cosine = cos(omega)
            let alpha = sin(omega) / (2 * q)
            let a0 = 1 + alpha
            switch shape {
            case .lowPass: (b0, b1, b2) = ((1 - cosine) / 2, 1 - cosine, (1 - cosine) / 2)
            case .highPass: (b0, b1, b2) = ((1 + cosine) / 2, -(1 + cosine), (1 + cosine) / 2)
            case .bandPass: (b0, b1, b2) = (alpha, 0, -alpha)
            }
            (b0, b1, b2) = (b0 / a0, b1 / a0, b2 / a0)
            a1 = -2 * cosine / a0
            a2 = (1 - alpha) / a0
        }

        mutating func process(_ x: Double) -> Double {
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1
            x1 = x
            y2 = y1
            y1 = y
            return y
        }
    }
}
