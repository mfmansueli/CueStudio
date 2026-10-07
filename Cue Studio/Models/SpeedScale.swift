//
//  SpeedScale.swift
//  Cue Studio
//

import Foundation

/// How a prompter speed reads to a creator: as a multiple of the natural reading pace, not in words a minute. 1× is the default pace (150 words
/// a minute); the speed slider stops on 0.5×, 0.8×, 1×, 1.2×, 1.5×, 2×, 3×, 4× and 5×: close together around the paces a creator reads at, far
/// apart for the fast ones. Every stop is a whole number of 5-word steps (`PrompterSettings.wordsPerMinuteStep`), so the stored speed is exactly
/// the stop's and the label never drifts from it.
nonisolated enum SpeedScale {
    /// The multiples the slider stops on, slowest first.
    static let stops: [Double] = [0.5, 0.8, 1, 1.2, 1.5, 2, 3, 4, 5]

    /// Words a minute at 1×: the natural pace, which is also the default speed.
    static let wordsPerMinuteAtOneX: Double = 150

    /// The stop that is 1×, where a new creator starts.
    static let defaultStop = 2

    /// The stored speed (a multiple of `ReadTime.wordsPerMinuteAtOneX`) that a multiple of the natural pace means.
    static func speed(forMultiple multiple: Double) -> Double {
        multiple * wordsPerMinuteAtOneX / ReadTime.wordsPerMinuteAtOneX
    }

    /// The other way: how many times the natural pace a stored speed is.
    static func multiple(forSpeed speed: Double) -> Double {
        speed * ReadTime.wordsPerMinuteAtOneX / wordsPerMinuteAtOneX
    }

    /// The index in `stops` of the stop closest to a stored speed (a speed saved between two stops shows on the nearer one).
    static func nearestStop(toSpeed speed: Double) -> Int {
        let multiple = multiple(forSpeed: speed)
        return stops.indices.min { abs(stops[$0] - multiple) < abs(stops[$1] - multiple) } ?? defaultStop
    }

    /// "1×", "0.5×", "1.2×": no decimal point on a whole number, the interface's decimal separator otherwise.
    static func label(forMultiple multiple: Double) -> String {
        multiple.formatted(.number.precision(.fractionLength(0...2)).locale(.interface)) + "×"
    }

    /// The label of a stored speed, to hundredths.
    static func label(forSpeed speed: Double) -> String {
        label(forMultiple: (multiple(forSpeed: speed) * 100).rounded() / 100)
    }
}
