//
//  CaptionEmphasisSize.swift
//  Cue Studio
//

import Foundation

/// How much bigger the words the creator marked for emphasis are (Caption style › Adjust › Emphasis): moderate, so a line
/// keeps its rhythm. They are measured at this size when lines are cut.
nonisolated enum CaptionEmphasisSize: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionEmphasisSize.bigger

    case same, bigger, biggest

    var id: String { rawValue }

    var label: String {
        switch self {
        case .same: String(localized: "Same")
        case .bigger: String(localized: "Bigger")
        case .biggest: String(localized: "Biggest")
        }
    }

    var scale: Double {
        switch self {
        case .same: 1
        case .bigger: 1.15
        case .biggest: 1.3
        }
    }

    /// The step a style's emphasis is nearest to.
    static func nearest(to scale: Double) -> CaptionEmphasisSize {
        allCases.min { abs($0.scale - scale) < abs($1.scale - scale) } ?? .bigger
    }
}
