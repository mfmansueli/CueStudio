//
//  VoiceDelayLine.swift
//  Cue Studio
//

import Foundation

/// A short memory of the voice fed back into itself, the building block of the voice effects that repeat or ring
/// (`VoiceEffectShaper`): an echo, a feedback comb (with the highs of each pass damped, as air and walls do) or an all-pass
/// that smears a sound in time without colouring it.
nonisolated struct VoiceDelayLine {
    private var buffer: [Double]
    private var index = 0
    private let feedback: Double
    /// How much of the highs each pass loses (0: none).
    private let damping: Double
    private var damped = 0.0

    init(samples: Int, feedback: Double, damping: Double = 0) {
        buffer = [Double](repeating: 0, count: max(1, samples))
        self.feedback = feedback
        self.damping = damping
    }

    init(seconds: Double, sampleRate: Double, feedback: Double, damping: Double = 0) {
        self.init(samples: Int((seconds * sampleRate).rounded()), feedback: feedback, damping: damping)
    }

    /// What went in `buffer.count` samples ago, as an effect to mix in; `x` and the damped repeat go back in.
    mutating func echo(_ x: Double) -> Double {
        let delayed = buffer[index]
        damped = delayed * (1 - damping) + damped * damping
        write(x + damped * feedback)
        return x + delayed
    }

    /// A feedback comb: the delayed signal, damped, fed back with the input.
    mutating func comb(_ x: Double) -> Double {
        let delayed = buffer[index]
        damped = delayed * (1 - damping) + damped * damping
        write(x + damped * feedback)
        return delayed
    }

    /// An all-pass (Schroeder's, as Freeverb writes it).
    mutating func allPass(_ x: Double) -> Double {
        let delayed = buffer[index]
        write(x + delayed * feedback)
        return delayed - x
    }

    private mutating func write(_ value: Double) {
        // Flushed to zero far below hearing, so a long tail never runs denormal.
        buffer[index] = abs(value) < 1e-20 ? 0 : value
        index = (index + 1) % buffer.count
    }
}
