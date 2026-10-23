//
//  BackgroundStyle.swift
//  Cue Studio
//

import Foundation

/// What goes behind the creator: the recording as it is, blurred, a color or a photo.
nonisolated enum BackgroundStyle: String, LenientChoice, CaseIterable, Identifiable, Sendable {
    /// Read in place of a value a newer version of Cue added (`LenientChoice`).
    static let fallback = BackgroundStyle.original

    case original, blur, color, image

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: String(localized: "Original")
        case .blur: String(localized: "Blur")
        case .color: String(localized: "Color")
        case .image: String(localized: "Image")
        }
    }
}
