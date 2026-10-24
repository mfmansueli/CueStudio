//
//  CaptionOutlineWeight.swift
//  Cue Studio
//

import Foundation

/// How thick the line around each letter is (Caption style › Adjust › Outline). A thick one is wide enough to be what the
/// words are read against (WCAG counts a narrow border as part of the letter, a wide one as its background).
nonisolated enum CaptionOutlineWeight: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CaptionOutlineWeight.thick

    case none, thin, thick

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .thin: String(localized: "Thin")
        case .thick: String(localized: "Thick")
        }
    }

    /// The stroke as a percent of the font size; nil for none.
    var width: Double? {
        switch self {
        case .none: nil
        case .thin: 3.5
        case .thick: 7
        }
    }

    /// The step a stroke of `width` percent is nearest to.
    static func nearest(to width: Double?) -> CaptionOutlineWeight {
        guard let width, width > 0 else { return .none }
        return width < 5 ? .thin : .thick
    }
}
