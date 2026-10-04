//
//  MarginPreset.swift
//  Cue Studio
//

import Foundation

/// How much room the prompter's text leaves at its sides (Settings › Prompter › Margins).
nonisolated enum MarginPreset: Int, CaseIterable, Identifiable, Sendable {
    case narrow, medium, wide

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .narrow: String(localized: "Narrow")
        case .medium: String(localized: "Medium")
        case .wide: String(localized: "Wide")
        }
    }

    /// Points on each side of the text (`PrompterSettings.margin`). Medium is the prompter's default.
    var points: Double {
        switch self {
        case .narrow: 2
        case .medium: 8
        case .wide: 20
        }
    }

    /// The preset nearest to a margin, so a margin set in Display still lights a step.
    init(points: Double) {
        self = Self.allCases.min { abs($0.points - points) < abs($1.points - points) } ?? .medium
    }
}
