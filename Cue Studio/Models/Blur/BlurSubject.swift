//
//  BlurSubject.swift
//  Cue Studio
//

import Foundation

/// What a Blur area was put on: a face Cue found (followed face to face, with room around it for the head and hair), or an
/// area the creator drew (a plate, a name on a screen, anything else; followed by what's inside it).
nonisolated enum BlurSubject: String, LenientChoice, CaseIterable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = BlurSubject.area

    case face, area

    var label: String {
        switch self {
        case .face: String(localized: "Face")
        case .area: String(localized: "Area", comment: "A Blur area the creator drew (not a face)")
        }
    }
}
