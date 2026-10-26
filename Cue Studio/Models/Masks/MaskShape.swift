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
        // Their own keys: "Line" and "Band" are also the captions' (a line of text, the band behind it), "Circle" the cover's ring.
        case .circle: String(inInterfaceLanguage: LocalizedStringResource("mask.circle", defaultValue: "Circle"))
        case .line: String(inInterfaceLanguage: LocalizedStringResource("mask.line", defaultValue: "Line"))
        case .band: String(inInterfaceLanguage: LocalizedStringResource("mask.band", defaultValue: "Band"))
        }
    }

    /// Width and height both mean something (a line only has a place and a turn; a band, its thickness).
    var hasSize: Bool { self == .rectangle || self == .circle }

    /// Only a rectangle has corners to round.
    var hasCorners: Bool { self == .rectangle }
}
