//
//  TextOverlayAlignment.swift
//  Cue Studio
//

import Foundation

/// How the lines of a text line up with each other.
nonisolated enum TextOverlayAlignment: String, Codable, CaseIterable, Identifiable, Sendable {
    case leading, center, trailing

    var id: String { rawValue }

    var label: String {
        switch self {
        case .leading: String(localized: "Left")
        case .center: String(localized: "Center")
        case .trailing: String(localized: "Right")
        }
    }

    var systemImage: String {
        switch self {
        case .leading: "text.alignleft"
        case .center: "text.aligncenter"
        case .trailing: "text.alignright"
        }
    }
}
