//
//  EyeTrackSmoother.swift
//  Cue Studio
//

import Foundation

/// Smooths a run of frames' eye points over time with a One-Euro filter (Casiez et al. 2012; Maxine's host filters its landmarks
/// the same way): nearly still while the eye rests, quick once it really moves. The recording is already filmed, so the filter runs
/// forward and backward and the two are averaged: no lag either way. Pure.
nonisolated enum EyeTrackSmoother {
    /// `values` (one vector per frame, all the same length) at `times`, smoothed.
    static func smooth(_ values: [[Double]], times: [TimeInterval], cutoff: Double, speed: Double) -> [[Double]] {
        guard values.count > 2, let width = values.first?.count, width > 0 else { return values }
        let forward = pass(values, times: times, cutoff: cutoff, speed: speed)
        let backward = Array(pass(values.reversed(), times: times.reversed().map { -$0 }, cutoff: cutoff, speed: speed).reversed())
        return zip(forward, backward).map { a, b in zip(a, b).map { ($0 + $1) / 2 } }
    }

    private static func pass(_ values: [[Double]], times: [TimeInterval], cutoff: Double, speed: Double) -> [[Double]] {
        var result = values
        var previous = values[0]
        var change = [Double](repeating: 0, count: previous.count)
        func alpha(_ cutoff: Double, _ step: Double) -> Double { 1 / (1 + 1 / (2 * .pi * cutoff * step)) }
        for index in 1..<values.count {
            let step = max(1.0 / 240, abs(times[index] - times[index - 1]))
            let changeAlpha = alpha(1, step)
            for dimension in 0..<previous.count {
                let rate = (values[index][dimension] - previous[dimension]) / step
                change[dimension] += changeAlpha * (rate - change[dimension])
                let valueAlpha = alpha(cutoff + speed * abs(change[dimension]), step)
                previous[dimension] += valueAlpha * (values[index][dimension] - previous[dimension])
            }
            result[index] = previous
        }
        return result
    }
}
