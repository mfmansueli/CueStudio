//
//  BeatTracker.swift
//  Cue Studio
//

import Accelerate
import Foundation

/// Finds the beats of a piece of music from its sound, on the iPhone: how much the spectrum rises from one short moment to the
/// next (spectral flux, on a log scale) is the onset strength; the tempo is the period that strength repeats at most (its
/// autocorrelation, leaning toward 120 BPM, between 60 and 200 BPM); the beats are the strongest onsets that keep to that
/// tempo, chosen all at once (Ellis' dynamic programming: each beat the best mix of a strong onset and an even step from the
/// one before). Pure: tested on click tracks of known tempo.
nonisolated enum BeatTracker {
    /// The sound it reads: mono, at this rate.
    static let sampleRate = 22_050.0
    /// Samples per analysis window, and between two (11.6 ms).
    static let window = 1024
    static let hop = 256
    /// Slowest and fastest tempo looked for, in beats a minute.
    static let tempoRange: ClosedRange<Double> = 60...200
    /// The tempo the search leans to, and how loosely (octaves).
    static let preferredTempo = 120.0
    static let tempoSpread = 1.0
    /// How strongly beats keep to the tempo.
    static let tightness = 100.0
    /// How far the tempo's period has to stand out of the others (its correlation over their mean) to be a pulse.
    static let minimumPulse = 1.4

    struct Result: Hashable, Sendable {
        /// Seconds into the sound.
        var beats: [TimeInterval]
        /// Beats a minute.
        var tempo: Double
    }

    /// Seconds between two onset readings.
    static var frameDuration: TimeInterval { Double(hop) / sampleRate }

    /// The beats of `samples` (mono, `sampleRate`); nil for a sound too short or without a pulse.
    static func beats(in samples: [Float]) -> Result? {
        let onsets = onsetStrength(samples)
        guard onsets.count > Int(4 / frameDuration) else { return nil }
        guard let period = tempoPeriod(onsets) else { return nil }
        let picked = track(onsets, period: period)
        guard picked.count >= 4 else { return nil }
        // A reading stands for the middle of its window.
        let center = Double(window / 2) / sampleRate
        return Result(beats: picked.map { Double($0) * frameDuration + center }, tempo: 60 / (Double(period) * frameDuration))
    }

    // MARK: - Onsets

    /// Spectral flux on a log magnitude spectrum, its slow average taken out and scaled to unit spread.
    static func onsetStrength(_ samples: [Float]) -> [Double] {
        guard samples.count > window, let dft = try? vDSP.DiscreteFourierTransform(
            count: window, direction: .forward, transformType: .complexComplex, ofType: Float.self
        ) else { return [] }
        let hann = vDSP.window(ofType: Float.self, usingSequence: .hanningDenormalized, count: window, isHalfWindow: false)
        let bins = window / 2
        var previous = [Float](repeating: 0, count: bins)
        var flux: [Double] = []
        flux.reserveCapacity(samples.count / hop)
        let zeros = [Float](repeating: 0, count: window)
        var start = 0
        while start + window <= samples.count {
            let frame = vDSP.multiply(Array(samples[start..<(start + window)]), hann)
            let (real, imaginary) = dft.transform(real: frame, imaginary: zeros)
            var magnitude = [Float](repeating: 0, count: bins)
            for bin in 0..<bins {
                magnitude[bin] = log1p(100 * sqrt(real[bin] * real[bin] + imaginary[bin] * imaginary[bin]))
            }
            var rise: Float = 0
            for bin in 0..<bins { rise += max(0, magnitude[bin] - previous[bin]) }
            // The first window rises from nothing: it isn't an onset.
            flux.append(flux.isEmpty && start == 0 ? 0 : Double(rise))
            previous = magnitude
            start += hop
        }
        // The slow average (about half a second) taken out, the rest kept above zero, scaled to unit spread.
        let reach = Int(0.25 / frameDuration)
        var local = [Double](repeating: 0, count: flux.count)
        var sum = 0.0
        for index in 0..<min(flux.count, reach) { sum += flux[index] }
        for index in flux.indices {
            let enter = index + reach, leave = index - reach - 1
            if enter < flux.count { sum += flux[enter] }
            if leave >= 0 { sum -= flux[leave] }
            let count = min(flux.count - 1, index + reach) - max(0, index - reach) + 1
            local[index] = max(0, flux[index] - sum / Double(count))
        }
        let mean = local.reduce(0, +) / Double(max(1, local.count))
        let spread = sqrt(local.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(max(1, local.count)))
        return spread > 0 ? local.map { $0 / spread } : local
    }

    // MARK: - Tempo

    /// The beat period (in onset readings) the onsets repeat at most, weighted toward `preferredTempo`; nil without a pulse.
    static func tempoPeriod(_ onsets: [Double]) -> Int? {
        let shortest = Int((60 / tempoRange.upperBound / frameDuration).rounded(.down))
        let longest = Int((60 / tempoRange.lowerBound / frameDuration).rounded(.up))
        guard onsets.count > longest * 2 else { return nil }
        // Softened over a couple of readings, so a period that falls between two readings counts as much as one on them (or
        // twice the period would win).
        let onsets = GaussianSmoothing.smoothed(onsets, sigma: 1.5)
        let preferred = 60 / preferredTempo / frameDuration
        var best: (lag: Int, score: Double)?
        var raw: [Double] = []
        for lag in shortest...longest {
            var sum = 0.0
            for index in lag..<onsets.count { sum += onsets[index] * onsets[index - lag] }
            let correlation = sum / Double(onsets.count - lag)
            raw.append(correlation)
            let octave = log2(Double(lag) / preferred) / tempoSpread
            let score = correlation * exp(-0.5 * octave * octave)
            if score > (best?.score ?? 0) { best = (lag, score) }
        }
        // A pulse stands out of the other periods; a sound without one (noise, speech) doesn't.
        let mean = raw.reduce(0, +) / Double(max(1, raw.count))
        guard let best, mean > 0, raw[best.lag - shortest] / mean >= minimumPulse else { return nil }
        return best.lag
    }

    // MARK: - Beats

    /// The beats as onset readings: Ellis' dynamic programming with `period`.
    static func track(_ onsets: [Double], period: Int) -> [Int] {
        let count = onsets.count
        var score = onsets
        var previous = [Int](repeating: -1, count: count)
        let low = max(1, period / 2), high = period * 2
        for index in 0..<count {
            var bestScore = -Double.infinity, bestFrom = -1
            let first = max(0, index - high), last = index - low
            if last >= first {
                for from in first...last {
                    let ratio = log(Double(index - from) / Double(period))
                    let candidate = score[from] - tightness * ratio * ratio
                    if candidate > bestScore {
                        bestScore = candidate
                        bestFrom = from
                    }
                }
            }
            if bestFrom >= 0 {
                score[index] = onsets[index] + bestScore
                previous[index] = bestFrom
            }
        }
        // The last beat: the best score in the last period, then back along the chain.
        let tail = max(0, count - period)
        var end = tail
        for index in tail..<count where score[index] > score[end] { end = index }
        var beats: [Int] = []
        var index = end
        while index >= 0 {
            beats.append(index)
            index = previous[index]
        }
        // No beats in the silence before the music starts or after it ends.
        let strong = onsets.indices.filter { onsets[$0] > 1 }
        guard let firstStrong = strong.first, let lastStrong = strong.last else { return [] }
        let margin = period / 2
        return beats.reversed().filter { $0 >= firstStrong - margin && $0 <= lastStrong + margin }
    }
}
