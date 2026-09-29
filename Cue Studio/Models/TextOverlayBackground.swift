//
//  TextOverlayBackground.swift
//  Cue Studio
//

import Foundation

/// What sits behind a text on the video.
nonisolated enum TextOverlayBackground: String, Codable, CaseIterable, Identifiable, Sendable {
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
