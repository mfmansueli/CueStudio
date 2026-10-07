//
//  VoiceStyle.swift
//  Cue Studio
//

import Foundation

/// "My style" in My Cue Voice. A creator can pick several.
nonisolated enum VoiceStyle: String, Codable, CaseIterable, Identifiable, Sendable {
    case shortSentences, storytelling, educational, opinionDriven, conversational

    var id: String { rawValue }

    var label: String {
        switch self {
        case .shortSentences: String(localized: "Short sentences")
        case .storytelling: String(localized: "Storytelling")
        case .educational: String(localized: "Educational")
        case .opinionDriven: String(localized: "Opinion-driven")
        case .conversational: String(localized: "Conversational")
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .shortSentences: "short sentences"
        case .storytelling: "storytelling"
        case .educational: "educational"
        case .opinionDriven: "opinionated"
        case .conversational: "conversational"
        }
    }
}
