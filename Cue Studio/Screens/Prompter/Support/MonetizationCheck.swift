//
//  MonetizationCheck.swift
//  Cue Studio
//

import Foundation

/// Warns before a take stops short of the platform's monetization minimum.
nonisolated enum MonetizationCheck {
    /// Seconds still missing, or nil when there is no minimum or it was reached.
    static func secondsMissing(elapsed: TimeInterval, preset: PlatformPreset?) -> TimeInterval? {
        guard let minimum = preset?.minimum, elapsed < minimum else { return nil }
        return minimum - elapsed
    }

    /// Chip next to the recording clock: "18s to 1:00" or "✓ Monetizable".
    static func chipLabel(elapsed: TimeInterval, preset: PlatformPreset?) -> String? {
        guard let minimum = preset?.minimum else { return nil }
        if let missing = secondsMissing(elapsed: elapsed, preset: preset) {
            return String(localized: "\(DurationText.remaining(missing)) to \(DurationText.clock(minimum))")
        }
        return String(localized: "✓ Monetizable")
    }

    /// "18s short of 1:00"
    static func warningTitle(elapsed: TimeInterval, preset: PlatformPreset?) -> String? {
        guard let minimum = preset?.minimum, let missing = secondsMissing(elapsed: elapsed, preset: preset) else { return nil }
        return String(localized: "\(DurationText.remaining(max(1, missing))) short of \(DurationText.clock(minimum))")
    }
}
