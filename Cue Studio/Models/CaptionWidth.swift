//
//  CaptionWidth.swift
//  Cue Studio
//

import Foundation

/// How wide a caption line may run (Caption style › Format › Width), as a share of the frame and never past the safe area.
/// Nil in `CaptionSettings`: the style's own width.
nonisolated enum CaptionWidth: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionWidth.medium

    case narrow, medium, wide

    var id: String { rawValue }

    var label: String {
        switch self {
        case .narrow: String(localized: "Narrow")
        case .medium: String(localized: "Medium")
        case .wide: String(localized: "Wide")
        }
    }

    var fraction: Double {
        switch self {
        case .narrow: 0.64
        case .medium: 0.78
        // BBC's vertical subtitles: up to 90% of the width.
        case .wide: 0.9
        }
    }

    /// The step a style's width is nearest to.
    static func nearest(to fraction: Double) -> CaptionWidth {
        allCases.min { abs($0.fraction - fraction) < abs($1.fraction - fraction) } ?? .medium
    }
}
