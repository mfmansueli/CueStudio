//
//  VoiceEnergy.swift
//  Cue Studio
//

import Foundation

nonisolated enum VoiceEnergy: String, Codable, CaseIterable, Identifiable, Sendable {
    case calm, balanced, high

    var id: String { rawValue }

    var label: String {
        switch self {
        case .calm: String(localized: "Calm")
        case .balanced: String(localized: "Balanced")
        case .high: String(localized: "High")
        }
    }

    /// What the AI reads (English, whatever the interface language is).
    var promptName: String {
        switch self {
        case .calm: "calm"
        case .balanced: "balanced"
        case .high: "high and lively"
        }
    }
}
