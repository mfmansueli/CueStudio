//
//  DurationText.swift
//  Cue Studio
//

import Foundation

/// Duration formats used across the app, kept in one place so every screen reads the same.
nonisolated enum DurationText {
    /// "45s" under a minute, "1:05" from a minute up. Never shows less than 1s.
    static func short(_ seconds: TimeInterval) -> String {
        let whole = max(1, Int(seconds.rounded()))
        return whole < 60 ? String(localized: "\(whole)s") : clock(TimeInterval(whole))
    }

    /// "m:ss", e.g. "0:44" or "12:03".
    static func clock(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded()))
        return "\(whole / 60):" + twoDigits(whole % 60)
    }

    /// Like `short`, but rounds up: used for time that is still missing ("12s to monetize").
    static func remaining(_ seconds: TimeInterval) -> String {
        let whole = max(1, Int(seconds.rounded(.up)))
        return whole < 60 ? String(localized: "\(whole)s") : clock(TimeInterval(whole))
    }

    /// "mm:ss" recording clock.
    static func recording(_ seconds: Int) -> String {
        let whole = max(0, seconds)
        return twoDigits(whole / 60) + ":" + twoDigits(whole % 60)
    }

    /// Quick edit's clock: "00:04.32" or "01:04.00" (minutes, seconds, hundredths) for a video under
    /// ten minutes, "00:12:04" (hours, minutes, seconds) from ten minutes up. `total` is the video's
    /// length and picks the format, so the playhead and the length always read alike.
    /// `precise` (the timeline zoomed in) keeps the hundredths on a long take too: "12:04.42".
    static func timecode(_ seconds: TimeInterval, total: TimeInterval, precise: Bool = false) -> String {
        let value = seconds.isFinite ? max(0, seconds) : 0
        if total < 600 || precise {
            let hundredths = Int((value * 100).rounded())
            return twoDigits(hundredths / 6000) + ":" + twoDigits(hundredths / 100 % 60) + "." + twoDigits(hundredths % 100)
        }
        let whole = Int(value.rounded())
        return twoDigits(whole / 3600) + ":" + twoDigits(whole / 60 % 60) + ":" + twoDigits(whole % 60)
    }

    /// The editor's clock, to a tenth: "00:04.1", "12:04.0".
    static func editor(_ seconds: TimeInterval) -> String {
        let value = seconds.isFinite ? max(0, seconds) : 0
        let tenths = Int((value * 10).rounded())
        return twoDigits(tenths / 600) + ":" + twoDigits(tenths / 10 % 60) + "." + String(tenths % 10)
    }

    /// A length to a tenth of a second: "1.8s", "0.7s".
    static func tenths(_ seconds: TimeInterval) -> String {
        let value = seconds.isFinite ? max(0, seconds) : 0
        return String(localized: "\(value.formatted(.number.precision(.fractionLength(1)).locale(.interface)))s")
    }

    /// A ruler label: "00:04", "01:12".
    static func ruler(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded()))
        return twoDigits(whole / 60) + ":" + twoDigits(whole % 60)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
