//
//  GaussianSmoothing.swift
//  Cue Studio
//

import Foundation

/// A series smoothed both ways (zero lag) with a Gaussian: Follow face's path, Stabilize's camera path, the beats' onsets.
nonisolated enum GaussianSmoothing {
    /// `values` smoothed both ways with a Gaussian of `sigma` samples (zero lag), the ends held.
    static func smoothed(_ values: [Double], sigma: Double) -> [Double] {
        guard values.count > 2, sigma > 0.5 else { return values }
        let reach = Int((sigma * 3).rounded(.up))
        let weights = (-reach...reach).map { exp(-Double($0 * $0) / (2 * sigma * sigma)) }
        let total = weights.reduce(0, +)
        return values.indices.map { index in
            var sum = 0.0
            for (offset, weight) in zip(-reach...reach, weights) {
                sum += values[min(max(0, index + offset), values.count - 1)] * weight
            }
            return sum / total
        }
    }
}
