//
//  SpeedScale.swift
//  Cue Studio
//

import Foundation

/// How a prompter speed reads to a creator: as a multiple of the natural reading pace, not in words a minute. 1× is the default pace (150 words
/// a minute); the speed slider stops every 0.1× from 0.2× (30 words a minute, a slow, deliberate read) to 2× (300, as fast as anyone reads
/// aloud): the owner's range (20/10/2026), in the same even steps everywhere. A tenth is 15 words a minute, three 5-word steps
/// (`PrompterSettings.wordsPerMinuteStep`), so the stored speed is exactly the stop's and the label never drifts from it.
nonisolated enum SpeedScale {
    /// The multiples the slider stops on, slowest first: 0.2×, 0.3× … 1.9×, 2×. Built from whole tenths so 0.3 is the 0.3 a label prints.
    static let stops: [Double] = (2...20).map { Double($0) / 10 }

    /// Words a minute at 1×: the natural pace, which is also the default speed.
    static let wordsPerMinuteAtOneX: Double = 150

    /// The stop that is 1×, where a new creator starts.
    static let defaultStop = stops.firstIndex(of: 1) ?? 0

    /// The slowest and fastest stored speeds, the ends of `PrompterSettings.speedRange`: nothing can be set or saved past them.
    static var slowestSpeed: Double { speed(forMultiple: stops[0]) }
    static var fastestSpeed: Double { speed(forMultiple: stops[stops.count - 1]) }

    /// The stored speed (a multiple of `ReadTime.wordsPerMinuteAtOneX`) that a multiple of the natural pace means. Counted from whole words a
    /// minute, so a stop's speed is bit for bit the one `PrompterSettings.clampedSpeed` lands on.
    static func speed(forMultiple multiple: Double) -> Double {
        (multiple * wordsPerMinuteAtOneX).rounded() / ReadTime.wordsPerMinuteAtOneX
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

    /// The speed `steps` stops away from the stop nearest `speed`, held to the ends: what a remote's − and + do, one stop a tap, like the slider.
    static func speed(steppedBy steps: Int, fromSpeed speed: Double) -> Double {
        let index = min(stops.count - 1, max(0, nearestStop(toSpeed: speed) + steps))
        return self.speed(forMultiple: stops[index])
    }

    /// "1×", "0.5×", "1.2×": no decimal point on a whole number, the interface's decimal separator otherwise.
    static func label(forMultiple multiple: Double) -> String {
        multiple.formatted(.number.precision(.fractionLength(0...2)).locale(.interface)) + "×"
    }

    /// The label of a stored speed: its nearest stop's, the one the slider shows (a speed saved between two stops, on the old 5-word steps,
    /// reads "1.1×" everywhere, not "1.07×" on the remote and "1.1×" on the slider).
    static func label(forSpeed speed: Double) -> String {
        label(forMultiple: stops[nearestStop(toSpeed: speed)])
    }
}
