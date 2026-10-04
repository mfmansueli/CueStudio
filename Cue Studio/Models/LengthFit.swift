//
//  LengthFit.swift
//  Cue Studio
//

import Foundation

/// How a recorded take's length sits against its platform's ideal range: it fits, or is a number of
/// seconds under or over. (A script's read time has `LengthZone`; this is for a finished video.)
nonisolated struct LengthFit: Equatable, Sendable {
    enum Verdict: Equatable, Sendable {
        case fits
        case under(TimeInterval)
        case over(TimeInterval)
    }

    let seconds: TimeInterval
    let ideal: ClosedRange<TimeInterval>

    var verdict: Verdict {
        if seconds < ideal.lowerBound { return .under(ideal.lowerBound - seconds) }
        if seconds > ideal.upperBound { return .over(seconds - ideal.upperBound) }
        return .fits
    }

    var fits: Bool { verdict == .fits }

    /// "1:00–1:30"
    var rangeLabel: String {
        DurationText.clock(ideal.lowerBound) + "–" + DurationText.clock(ideal.upperBound)
    }

    /// "✓ Fits 1:00–1:30", "12s under 1:00–1:30", "8s over 1:00–1:30".
    var label: String {
        switch verdict {
        case .fits: String(localized: "✓ Fits \(rangeLabel)")
        case .under(let gap): String(localized: "\(DurationText.remaining(gap)) under \(rangeLabel)")
        case .over(let gap): String(localized: "\(DurationText.remaining(gap)) over \(rangeLabel)")
        }
    }
}
