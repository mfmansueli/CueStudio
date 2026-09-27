//
//  Vocabulary.swift
//  Cue Studio
//

import Foundation

/// "My vocabulary" in Creator Voice.
nonisolated enum Vocabulary: String, Codable, CaseIterable, Identifiable, Sendable {
    case simple, technical, genZ, professional

    var id: String { rawValue }

    var label: String {
        switch self {
        case .simple: String(localized: "Simple")
        case .technical: String(localized: "Technical")
        case .genZ: String(localized: "Gen Z")
        case .professional: String(localized: "Professional")
        }
    }
}
