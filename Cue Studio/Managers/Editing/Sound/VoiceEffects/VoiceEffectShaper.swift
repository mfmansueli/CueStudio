//
//  VoiceEffectShaper.swift
//  Cue Studio
//

import Foundation

/// The voice effects Cue shapes sample by sample, one channel at a time (`VoiceEffectRenderer` sends Deep voice and Chipmunk
/// through Apple's time-pitch unit instead): Radio cuts the voice to a telephone's band and warms it a little; Megaphone cuts it
/// narrower, pushes its middle and overdrives it; Robot rings it against a low tone and through a short metallic comb; Echo
/// repeats it a third of a second later, each repeat darker; Big hall sends it into a large room (a Freeverb: eight damped
/// combs, then four all-passes). "Amount" narrows the band, drives harder, repeats longer or makes the room wetter, and mixes
/// in less of the voice as it was. Nothing here reads the clock or a random number: the same file comes out every time.
nonisolated struct VoiceEffectShaper {
    private var filters: [VoiceBiquad] = []
    /// How hard the voice is driven into `tanh`; nil leaves it linear.
    private var drive: Double?
    /// Share of the effect in the result (the rest is the voice as it was).
    private var wet: Double
    /// Ring modulation: the low tone the voice is multiplied by, and where it is.
    private var ringStep: Double?
    private var ringPhase = 0.0
    /// Delay lines fed back into themselves (Robot's comb, Echo's repeat, the hall's combs), with their feedback and damping.
    private var lines: [VoiceDelayLine] = []
    /// The hall's all-passes, after its combs.
    private var diffusers: [VoiceDelayLine] = []

    /// The shaper for `setting` at `sampleRate`; nil for an effect made by Apple's units instead (Deep voice, Chipmunk).
    init?(setting: VoiceEffectSetting, sampleRate: Double) {
        let amount = setting.amount
        switch setting.effect {
        case .radio:
            let low = 300 + 300 * amount, high = 3800 - 1200 * amount
            filters = Self.band(low, high, sampleRate: sampleRate) + [.peak(1800, q: 1, decibels: 4, sampleRate: sampleRate)]
            drive = 1 + 4 * amount
            wet = 0.4 + 0.6 * amount
        case .megaphone:
            let low = 500 + 300 * amount, high = 4500 - 1500 * amount
            filters = Self.band(low, high, sampleRate: sampleRate) + [.peak(2200, q: 1.2, decibels: 6, sampleRate: sampleRate)]
            drive = 3 + 9 * amount
            wet = 0.5 + 0.5 * amount
        case .robot:
            filters = [.highPass(120, sampleRate: sampleRate), .lowPass(6000, sampleRate: sampleRate)]
            drive = 1.5
            wet = 0.5 + 0.5 * amount
            ringStep = 2 * Double.pi * 55 / sampleRate
            lines = [VoiceDelayLine(seconds: 0.007, sampleRate: sampleRate, feedback: 0.35 + 0.3 * amount)]
        case .echo:
            wet = 0.2 + 0.3 * amount
            lines = [VoiceDelayLine(seconds: 0.32, sampleRate: sampleRate, feedback: 0.25 + 0.35 * amount, damping: 0.35)]
        case .hall:
            wet = 0.15 + 0.35 * amount
            // Freeverb's tunings (at 44.1 kHz), scaled to the file's rate; a large room, its highs damped.
            let scale = sampleRate / 44_100
            lines = [1116, 1188, 1277, 1356, 1422, 1491, 1557, 1617].map { length in
                VoiceDelayLine(samples: Int(Double(length) * scale), feedback: 0.84 + 0.1 * amount, damping: 0.3)
            }
            diffusers = [556, 441, 341, 225].map { length in VoiceDelayLine(samples: Int(Double(length) * scale), feedback: 0.5) }
        case .deep, .chipmunk:
            return nil
        }
    }

    /// Two high cuts at `low` and two low cuts at `high`: a steep band, as a small speaker has.
    private static func band(_ low: Double, _ high: Double, sampleRate: Double) -> [VoiceBiquad] {
        [
            .highPass(low, sampleRate: sampleRate), .highPass(low, sampleRate: sampleRate),
            .lowPass(high, sampleRate: sampleRate), .lowPass(high, sampleRate: sampleRate),
        ]
    }

    mutating func process(_ sample: Float) -> Float {
        let dry = Double(sample)
        var x = dry
        for index in filters.indices { x = filters[index].process(x) }
        if let ringStep {
            x *= sin(ringPhase)
            ringPhase += ringStep
            if ringPhase > 2 * Double.pi { ringPhase -= 2 * Double.pi }
        }
        if !diffusers.isEmpty {
            // The hall: the combs side by side, then the all-passes in a row.
            var room = 0.0
            for index in lines.indices { room += lines[index].comb(x * 0.015) }
            for index in diffusers.indices { room = diffusers[index].allPass(room) }
            x = room
        } else if !lines.isEmpty {
            for index in lines.indices { x = lines[index].echo(x) }
        }
        if let drive {
            // Soft saturation, normalised so a full-scale sample stays near full scale.
            x = tanh(x * drive) / tanh(drive)
        }
        return Float(dry * (1 - wet) + x * wet)
    }
}
