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

    private static func twoDigits(_ value: Int) -> String {
        value < 10 ? "0\(value)" : "\(value)"
    }
}
