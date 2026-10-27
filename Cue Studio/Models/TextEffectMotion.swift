//
//  TextEffectMotion.swift
//  Cue Studio
//

import Foundation

/// Whether a text effect plays its own way in and out, or stays still with its finish the whole time.
nonisolated enum TextEffectMotion: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    static let fallback = TextEffectMotion.animated

    /// Its way in, a still time to be read, its way out.
    case animated
    /// The finish only, the whole time it shows.
    case still

    var id: String { rawValue }

    var label: String {
        switch self {
        case .animated: String(localized: "Animated", comment: "Text effect motion: plays its way in and out")
        case .still: String(localized: "Still", comment: "Text effect motion: the finish only, no motion")
        }
    }
}
