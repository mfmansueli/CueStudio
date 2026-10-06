//
//  Keyframes.swift
//  Cue Studio
//

import SwiftUI

/// One CSS property animated by `@keyframes`: stops at percentages of the cycle, each interval eased with the animation's timing function (as CSS does).
/// Before the first stop and after the last one the value holds. The boards' stories are written this way, so a story reads like its board.
nonisolated struct Keyframes {
    private let stops: [(percent: Double, value: Double)]
    private let curve: UnitCurve
    private let duration: Double

    /// - Parameters:
    ///   - stops: `(percent, value)` pairs in order, e.g. `[(0, 0), (20, 0), (36.25, 1)]`.
    ///   - curve: the timing function of the animation, applied inside each interval.
    ///   - duration: seconds in the whole cycle (the board's `8s`).
    init(_ stops: [(Double, Double)], curve: UnitCurve = .linear, duration: Double) {
        self.stops = stops.map { (percent: $0.0, value: $0.1) }
        self.curve = curve
        self.duration = duration
    }

    func value(at time: Double) -> Double {
        let percent = time / duration * 100
        guard let first = stops.first, let last = stops.last else { return 0 }
        if percent <= first.percent { return first.value }
        if percent >= last.percent { return last.value }
        guard let index = stops.indices.dropFirst().first(where: { percent < stops[$0].percent }) else { return last.value }
        let from = stops[index - 1]
        let to = stops[index]
        let local = (percent - from.percent) / (to.percent - from.percent)
        return from.value + (to.value - from.value) * curve.value(at: local)
    }
}
