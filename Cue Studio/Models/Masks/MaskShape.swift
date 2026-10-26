//
//  MaskShape.swift
//  Cue Studio
//

import Foundation

/// The shape of a mask on a photo or video over the take (`MediaMask`): only what's inside shows (outside, with Invert).
nonisolated enum MaskShape: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = MaskShape.rectangle

    case rectangle
    /// A circle or, stretched, an ellipse.
    case circle
    /// A straight line across: the side it faces shows.
    case line
    /// A strip between two parallel lines.
    case band

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rectangle: String(localized: "Rectangle")
        case .circle: String(localized: "Circle")
        case .line: String(localized: "Line")
        case .band: String(localized: "Band")
        }
    }

    /// Width and height both mean something (a line only has a place and a turn; a band, its thickness).
    var hasSize: Bool { self == .rectangle || self == .circle }

    /// Only a rectangle has corners to round.
    var hasCorners: Bool { self == .rectangle }
}
