//
//  PlaybackSpeed.swift
//  Cue Studio
//

import Foundation

/// The Speed tool's presets. No ramps: a section plays at one speed from start to end.
nonisolated enum PlaybackSpeed: Double, CaseIterable, Identifiable, Sendable {
    case half = 0.5
    case threeQuarters = 0.75
    case normal = 1
    case oneAndAQuarter = 1.25
    case oneAndAHalf = 1.5
    case double = 2

    var id: Double { rawValue }

    /// "1.25×"
    var label: String {
        rawValue.formatted(.number.precision(.fractionLength(0...2))) + "×"
    }

    /// The preset closest to `rate`.
    static func nearest(to rate: Double) -> PlaybackSpeed {
        allCases.min { abs($0.rawValue - rate) < abs($1.rawValue - rate) } ?? .normal
    }
}
