//
//  BlurShape.swift
//  Cue Studio
//

import Foundation

/// The shape of a Blur area: a box (a plate, a line of text, a screen) or an oval (a face).
nonisolated enum BlurShape: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`): the box, which covers the most.
    static let fallback = BlurShape.rectangle

    case rectangle, oval

    var id: String { rawValue }

    var label: String {
        switch self {
        case .rectangle: String(localized: "Rectangle")
        case .oval: String(localized: "Oval")
        }
    }

    var systemImage: String {
        switch self {
        case .rectangle: "rectangle"
        case .oval: "oval"
        }
    }
}
