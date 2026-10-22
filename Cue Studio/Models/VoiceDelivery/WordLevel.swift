//
//  WordLevel.swift
//  Cue Studio
//

import Foundation

nonisolated enum WordLevel: String, Codable, CaseIterable, Identifiable, Sendable {
    case plain, someSlang, expertTerms

    var id: String { rawValue }

    var label: String {
        switch self {
        case .plain: String(localized: "Plain")
        case .someSlang: String(localized: "Some slang")
        case .expertTerms: String(localized: "Expert terms")
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .plain: "plain and everyday"
        case .someSlang: "some casual slang"
        case .expertTerms: "the field's expert terms"
        }
    }
}
