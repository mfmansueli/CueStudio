//
//  CoverTextBackground.swift
//  Cue Studio
//

import Foundation

/// What keeps a cover's words readable over its picture.
nonisolated enum CoverTextBackground: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = CoverTextBackground.none

    /// The words alone.
    case none
    /// A soft shadow under the words.
    case shadow
    /// A dark stroke around each letter.
    case outline
    /// The whole block on a rounded box.
    case box

    var id: String { rawValue }

    var label: String {
        switch self {
        case .none: String(localized: "None")
        case .shadow: String(localized: "Shadow")
        case .outline: String(localized: "Outline")
        case .box: String(localized: "Box")
        }
    }
}
