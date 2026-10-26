//
//  BlurStyle.swift
//  Cue Studio
//

import Foundation

/// How Blur area hides what's under it. None has a weak setting: a light blur or fine pixels leave a face recognizable, more so
/// in video (research in DESIGN_PROJECT §54), so the weakest of each still hides; Solid hides completely.
nonisolated enum BlurStyle: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`): the coarse pixels, which still hide.
    static let fallback = BlurStyle.pixelate

    case blur, pixelate
    /// An opaque bar: nothing of the picture is left. The one to use for text, plates and screens.
    case solid

    var id: String { rawValue }

    var label: String {
        switch self {
        case .blur: String(localized: "Blur", comment: "Blur area's style: a heavy blur")
        case .pixelate: String(localized: "Pixelate")
        case .solid: String(localized: "Solid", comment: "Blur area's style: an opaque bar over what's hidden")
        }
    }

    var systemImage: String {
        switch self {
        case .blur: "drop.halffull"
        case .pixelate: "square.grid.3x3.fill"
        case .solid: "rectangle.fill"
        }
    }

    /// Whether Strength changes it (a solid bar is always whole).
    var hasStrength: Bool { self != .solid }
}
