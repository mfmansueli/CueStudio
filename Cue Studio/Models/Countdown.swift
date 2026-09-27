//
//  Countdown.swift
//  Cue Studio
//

import Foundation

/// Seconds counted down before a take starts recording.
nonisolated enum Countdown: Int, Codable, CaseIterable, Identifiable, Sendable {
    case off = 0
    case three = 3
    case five = 5
    case ten = 10

    var id: Int { rawValue }

    var label: String {
        self == .off ? String(localized: "Off") : String(localized: "\(rawValue)s")
    }

    /// Compact label for the countdown button in the camera toolbar.
    var shortLabel: String {
        self == .off ? String(localized: "OFF") : String(localized: "\(rawValue)s")
    }

    var next: Countdown {
        let all = Self.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }
}
