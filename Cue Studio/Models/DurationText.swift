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

    /// Quick edit's clock: "00:04.32" (minutes, seconds, hundredths) for a video under a minute,
    /// "00:01:04" (hours, minutes, seconds) from a minute up. `total` is the video's length and
    /// picks the format, so the playhead and the length always read alike.
    static func timecode(_ seconds: TimeInterval, total: TimeInterval) -> String {
        let value = seconds.isFinite ? max(0, seconds) : 0
        if total < 60 {
            let hundredths = Int((value * 100).rounded())
            return twoDigits(hundredths / 6000) + ":" + twoDigits(hundredths / 100 % 60) + "." + twoDigits(hundredths % 100)
        }
        let whole = Int(value.rounded())
        return twoDigits(whole / 3600) + ":" + twoDigits(whole / 60 % 60) + ":" + twoDigits(whole % 60)
    }

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
