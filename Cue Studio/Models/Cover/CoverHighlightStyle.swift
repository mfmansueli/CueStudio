//
//  CoverHighlightStyle.swift
//  Cue Studio
//

import Foundation

/// How a cover's highlighted words stand out: in the accent color, or on a box of it.
nonisolated enum CoverHighlightStyle: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CoverHighlightStyle.color

    case color, box

    var id: String { rawValue }

    var label: String {
        switch self {
        case .color: String(localized: "Color")
        case .box: String(localized: "Box")
        }
    }
}
