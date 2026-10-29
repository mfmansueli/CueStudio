//
//  VoiceBiquad.swift
//  Cue Studio
//

import Foundation

/// One second-order filter of the voice effects (the RBJ "Audio EQ Cookbook" biquads): a low or high cut, or a bell that lifts
/// a band. Its state is in `Double`, so a long file never drifts or goes denormal.
nonisolated struct VoiceBiquad {
    private var b0 = 1.0, b1 = 0.0, b2 = 0.0, a1 = 0.0, a2 = 0.0
    private var x1 = 0.0, x2 = 0.0, y1 = 0.0, y2 = 0.0

    /// Lets through what's under `frequency`.
    static func lowPass(_ frequency: Double, q: Double = 0.707, sampleRate: Double) -> VoiceBiquad {
        let (cosine, alpha) = shape(frequency, q: q, sampleRate: sampleRate)
        return VoiceBiquad(b0: (1 - cosine) / 2, b1: 1 - cosine, b2: (1 - cosine) / 2, a0: 1 + alpha, a1: -2 * cosine, a2: 1 - alpha)
    }

    /// Lets through what's over `frequency`.
    static func highPass(_ frequency: Double, q: Double = 0.707, sampleRate: Double) -> VoiceBiquad {
        let (cosine, alpha) = shape(frequency, q: q, sampleRate: sampleRate)
        return VoiceBiquad(b0: (1 + cosine) / 2, b1: -(1 + cosine), b2: (1 + cosine) / 2, a0: 1 + alpha, a1: -2 * cosine, a2: 1 - alpha)
    }

    /// Lifts (or lowers) the band around `frequency` by `decibels`.
    static func peak(_ frequency: Double, q: Double, decibels: Double, sampleRate: Double) -> VoiceBiquad {
        let (cosine, alpha) = shape(frequency, q: q, sampleRate: sampleRate)
        let gain = pow(10, decibels / 40)
        return VoiceBiquad(
            b0: 1 + alpha * gain, b1: -2 * cosine, b2: 1 - alpha * gain, a0: 1 + alpha / gain, a1: -2 * cosine, a2: 1 - alpha / gain
        )
    }

    private init(b0: Double, b1: Double, b2: Double, a0: Double, a1: Double, a2: Double) {
        self.b0 = b0 / a0
        self.b1 = b1 / a0
        self.b2 = b2 / a0
        self.a1 = a1 / a0
        self.a2 = a2 / a0
    }

    private static func shape(_ frequency: Double, q: Double, sampleRate: Double) -> (cosine: Double, alpha: Double) {
        let omega = 2 * Double.pi * min(frequency, sampleRate * 0.45) / sampleRate
        return (cos(omega), sin(omega) / (2 * q))
    }

    mutating func process(_ x: Double) -> Double {
        let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2 = x1
        x1 = x
        y2 = y1
        // Flushed to zero far below hearing, so silence after a word never runs denormal.
        y1 = abs(y) < 1e-20 ? 0 : y
        return y1
    }
}
