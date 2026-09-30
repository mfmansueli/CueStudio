//
//  CaptionAccent.swift
//  Cue Studio
//

import Foundation

/// Content colors, shared by the thumbnail, player and exported pixels.
nonisolated enum CaptionAccent: String, Codable, CaseIterable, Identifiable, Sendable {
    case yellow, lime, peach, white

    var id: String { rawValue }

    var components: (red: Double, green: Double, blue: Double) {
        switch self {
        case .yellow: (1, 0.86, 0.08)
        case .lime: (0.75, 1, 0.16)
        case .peach: (1, 0.73, 0.59)
        case .white: (1, 1, 1)
        }
    }

    var label: String {
        switch self {
        case .yellow: String(localized: "Yellow")
        case .lime: String(localized: "Lime")
        case .peach: String(localized: "Peach")
        case .white: String(localized: "White")
        }
    }
}
