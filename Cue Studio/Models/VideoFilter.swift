//
//  VideoFilter.swift
//  Cue Studio
//

import Foundation

/// Looks in Quick edit › Filters.
nonisolated enum VideoFilter: String, Codable, CaseIterable, Identifiable, Sendable {
    case original, vivid, warm, cool, mono, film

    var id: String { rawValue }

    var label: String {
        switch self {
        case .original: String(localized: "Original")
        case .vivid: String(localized: "Vivid")
        case .warm: String(localized: "Warm")
        case .cool: String(localized: "Cool")
        case .mono: String(localized: "Mono")
        case .film: String(localized: "Film")
        }
    }
}
