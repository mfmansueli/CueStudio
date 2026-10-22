//
//  SentenceLength.swift
//  Cue Studio
//

import Foundation

nonisolated enum SentenceLength: String, Codable, CaseIterable, Identifiable, Sendable {
    case short, mixed, long

    var id: String { rawValue }

    var label: String {
        switch self {
        case .short: String(localized: "Short")
        case .mixed: String(localized: "Mixed")
        case .long: String(localized: "Long")
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .short: "short and punchy (under twelve words)"
        case .mixed: "a mix of short and longer"
        case .long: "longer and flowing, building an argument"
        }
    }
}
