//
//  BackgroundStyle.swift
//  Cue Studio
//

import Foundation

/// What goes behind the creator: the recording as it is, blurred, a color or a photo.
nonisolated enum BackgroundStyle: String, Codable, CaseIterable, Identifiable, Sendable {
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
