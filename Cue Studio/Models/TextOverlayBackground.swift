//
//  TextOverlayBackground.swift
//  Cue Studio
//

import Foundation

/// What sits behind a text on the video.
nonisolated enum TextOverlayBackground: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = TextOverlayBackground.none

    case none, box, pill

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .box: String(localized: "Box")
        case .pill: String(localized: "Pill")
        }
    }
}
