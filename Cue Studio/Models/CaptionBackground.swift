//
//  CaptionBackground.swift
//  Cue Studio
//

import Foundation

/// What sits behind the caption's words (Caption style › Adjust › Background): nothing (the outline or the halo keeps them
/// readable), one box around the whole caption, a box behind each line, a square band behind each line, or a pill behind
/// each line.
nonisolated enum CaptionBackground: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionBackground.box

    case none, box, lines, band, pill

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .box: String(localized: "Box")
        case .lines: String(localized: "Lines", comment: "Caption background: a box behind each line")
        case .band: String(localized: "Band", comment: "Caption background: a square band behind each line")
        case .pill: String(localized: "Pill")
        }
    }

    /// The plate drawn in `color` (its alpha the opacity), with corners and room around the words for each kind.
    func plate(_ color: CaptionStyleSpec.RGB) -> CaptionStyleSpec.Plate {
        switch self {
        case .none: .none
        case .box: .block(color: color, radius: 8, insetX: 12, insetY: 5)
        case .lines: .perLine(color: color, radius: 8, insetX: 10, insetY: 3)
        case .band: .perLine(color: color, radius: 0, insetX: 16, insetY: 4)
        // As round as the line is tall: the drawing keeps a corner to half the line's height.
        case .pill: .perLine(color: color, radius: 999, insetX: 14, insetY: 4)
        }
    }

    /// The kind a preset's plate is.
    init(_ plate: CaptionStyleSpec.Plate) {
        switch plate {
        case .none: self = .none
        case .block: self = .box
        case .perLine(_, let radius, _, _): self = radius >= 999 ? .pill : radius == 0 ? .band : .lines
        }
    }
}
