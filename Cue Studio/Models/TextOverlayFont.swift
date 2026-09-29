//
//  TextOverlayFont.swift
//  Cue Studio
//

import Foundation

/// Typefaces for texts on the video: the system's designs, so every weight exists and nothing
/// has to be bundled.
nonisolated enum TextOverlayFont: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic, rounded, serif, mono

    var id: String { rawValue }

    var label: String {
        switch self {
        case .classic: String(localized: "Classic")
        case .rounded: String(localized: "Rounded")
        case .serif: String(localized: "Serif")
        case .mono: String(localized: "Mono")
        }
    }
}
