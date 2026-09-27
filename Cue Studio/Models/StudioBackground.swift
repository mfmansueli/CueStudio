//
//  StudioBackground.swift
//  Cue Studio
//

import Foundation

/// Background colors offered for Studio mode. Stored as hex so the model stays free of SwiftUI.
nonisolated enum StudioBackground: String, Codable, CaseIterable, Identifiable, Sendable {
    case black = "#000000"
    case graphite = "#1C1C1E"
    case navy = "#0B1A2E"

    var id: String { rawValue }

    var hex: String { rawValue }

    var label: String {
        switch self {
        case .black: String(localized: "Black")
        case .graphite: String(localized: "Graphite")
        case .navy: String(localized: "Navy")
        }
    }
}
