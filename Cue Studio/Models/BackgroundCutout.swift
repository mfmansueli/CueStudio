//
//  BackgroundCutout.swift
//  Cue Studio
//

import Foundation

/// How the creator is told apart from the background: the person found in each frame (Vision, on
/// the iPhone), or every color except the one of a green or blue screen (a chroma key).
nonisolated enum BackgroundCutout: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = BackgroundCutout.person

    case person, colorKey

    var id: String { rawValue }

    var label: String {
        switch self {
        case .person: String(localized: "Person")
        case .colorKey: String(localized: "Color key")
        }
    }
}
