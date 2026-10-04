//
//  CaptionSize.swift
//  Cue Studio
//

import Foundation

/// The four sizes of a caption (Caption style › Size): S · M · L · XL, on the design's 402-point frame.
nonisolated enum CaptionSize: Int, CaseIterable, Identifiable, Sendable {
    case small, medium, large, extraLarge

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .small: String(localized: "S")
        case .medium: String(localized: "M")
        case .large: String(localized: "L")
        case .extraLarge: String(localized: "XL")
        }
    }

    var points: Double {
        switch self {
        case .small: 14
        case .medium: 18
        case .large: 22
        case .extraLarge: 28
        }
    }

    /// The size a point size is nearest to, so a caption sized by dragging or by an older edit still lights a step.
    static func nearest(to points: Double) -> CaptionSize {
        allCases.min { abs($0.points - points) < abs($1.points - points) } ?? .medium
    }
}
