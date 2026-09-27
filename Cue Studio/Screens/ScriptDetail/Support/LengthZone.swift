//
//  LengthZone.swift
//  Cue Studio
//

import Foundation

/// Where a script's read time falls against its destination's ideal range and monetization minimum.
nonisolated struct LengthZone: Equatable, Sendable {
    let words: Int
    let seconds: TimeInterval
    let preset: PlatformPreset

    init(text: String, preset: PlatformPreset, speed: Double) {
        words = ReadTime.wordCount(in: text)
        seconds = ReadTime.seconds(for: text, speed: speed)
        self.preset = preset
    }

    /// Right end of the meter: a bit past the ideal range, or past the script if it is longer.
    var scaleMax: TimeInterval {
        max(preset.idealRange.upperBound * 1.2, seconds * 1.08)
    }

    var isBelowMinimum: Bool {
        guard let minimum = preset.minimum else { return false }
        return seconds < minimum
    }

    var isInIdealRange: Bool {
        !isBelowMinimum && preset.idealRange.contains(seconds)
    }

    var fillFraction: Double { min(1, seconds / scaleMax) }
    var idealStartFraction: Double { preset.idealRange.lowerBound / scaleMax }
    var idealWidthFraction: Double { (preset.idealRange.upperBound - preset.idealRange.lowerBound) / scaleMax }
    var minimumFraction: Double? { preset.minimum.map { $0 / scaleMax } }

    var durationLabel: String {
        words == 0 ? String(localized: "0s") : "~" + DurationText.short(seconds)
    }

    var status: String {
        let ideal = preset.idealRange
        if isBelowMinimum, let minimum = preset.minimum, let goal = preset.goal {
            return String(localized: "\(DurationText.remaining(minimum - seconds)) to \(goal.targetLabel)")
        }
        if seconds < ideal.lowerBound {
            return String(localized: "\(DurationText.remaining(ideal.lowerBound - seconds)) under ideal")
        }
        if seconds > ideal.upperBound {
            return String(localized: "\(DurationText.remaining(seconds - ideal.upperBound)) over ideal")
        }
        return String(localized: "In the ideal range")
    }

    /// "1:00 · monetizes"
    var minimumLabel: String? {
        guard let minimum = preset.minimum, let goal = preset.goal else { return nil }
        return DurationText.clock(minimum) + " · " + goal.meterLabel
    }

    var scaleMaxLabel: String { DurationText.clock(scaleMax) }
}
