//
//  TimelineRuler.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// The ruler's ticks: the step follows the zoom (half a second zoomed in, then 1, 2 and 5
/// seconds), and every second tick is a major one with its "mm:ss" label. Pure.
nonisolated enum TimelineRuler {
    struct Tick: Equatable, Sendable {
        var time: TimeInterval
        var isMajor: Bool
        /// "00:04" on major ticks.
        var label: String?
    }

    /// Seconds between ticks at `pointsPerSecond`.
    static func step(at pointsPerSecond: CGFloat) -> TimeInterval {
        if pointsPerSecond >= 150 { return 0.5 }
        if pointsPerSecond >= 60 { return 1 }
        if pointsPerSecond >= 28 { return 2 }
        return 5
    }

    /// The ticks between `from` and `to` (edited seconds), inside the video.
    static func ticks(from: TimeInterval, to: TimeInterval, duration: TimeInterval, pointsPerSecond: CGFloat) -> [Tick] {
        let step = step(at: pointsPerSecond)
        let major = step * 2
        let first = max(0, (max(0, from) / step).rounded(.down) * step)
        let last = min(duration, to)
        guard last >= first else { return [] }
        var ticks: [Tick] = []
        var index = (first / step).rounded()
        while index * step <= last + 0.000_1 {
            let time = index * step
            let isMajor = abs(time / major - (time / major).rounded()) < 0.000_1
            ticks.append(Tick(time: time, isMajor: isMajor, label: isMajor ? DurationText.ruler(time) : nil))
            index += 1
        }
        return ticks
    }
}
