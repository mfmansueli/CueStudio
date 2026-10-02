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

    /// The same choice as the audience it is for, as the voice setup asks it ("Who do you talk to?").
    var audienceLabel: String {
        switch self {
        case .simple: String(localized: "Everyday people")
        case .technical: String(localized: "People who know the field")
        case .genZ: String(localized: "A young crowd")
        case .professional: String(localized: "Professionals")
        }
    }
}
