//
//  CueSliderMath.swift
//  Cue Studio
//

import Foundation

/// Where a `CueSlider`'s thumb is for a value, and what value a touch means: pure, so it is tested
/// apart from drawing. The thumb's center travels from half its width to the track's end minus
/// half, so it never leaves the track.
nonisolated enum CueSliderMath {
    /// 0...1: how far `value` is along `range` (a value outside it is held at the nearest end).
    static func fraction(of value: Double, in range: ClosedRange<Double>) -> Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return min(1, max(0, (value - range.lowerBound) / span))
    }

    /// The value a touch at `x` (in the track's own coordinates) chooses, snapped to `step`.
    static func value(
        atX x: Double, width: Double, thumb: Double, range: ClosedRange<Double>, step: Double
    ) -> Double {
        let travel = width - thumb
        guard travel > 0 else { return range.lowerBound }
        let fraction = min(1, max(0, (x - thumb / 2) / travel))
        return snapped(range.lowerBound + fraction * (range.upperBound - range.lowerBound), step: step, in: range)
    }

    /// `value` on the nearest multiple of `step` from the range's start, held inside the range and
    /// free of floating point dust (0.7000000000000001 is 0.7).
    static func snapped(_ value: Double, step: Double, in range: ClosedRange<Double>) -> Double {
        guard step > 0 else { return min(range.upperBound, max(range.lowerBound, value)) }
        let steps = ((value - range.lowerBound) / step).rounded()
        let snapped = range.lowerBound + steps * step
        let clean = (snapped * 1_000).rounded() / 1_000
        return min(range.upperBound, max(range.lowerBound, clean))
    }
}
