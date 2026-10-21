//
//  VoiceField.swift
//  Cue Studio
//

import Foundation

/// The weights of `voiceStrength` (08 §1, total 100): what My Cue Voice counts as filled.
nonisolated enum VoiceField: String, CaseIterable, Identifiable, Sendable {
    case role, topics, audience, tone
    case style, formats, openings, endings, phrases, avoid, reach
    case examples

    var id: String { rawValue }

    var weight: Int {
        switch self {
        case .role, .topics, .audience, .tone: 10
        case .style, .formats, .openings, .endings, .phrases: 6
        case .avoid, .reach: 5
        case .examples: 20
        }
    }

    var layer: VoiceLayer {
        switch self {
        case .role, .topics, .audience, .tone: .essentials
        case .examples: .proof
        default: .personality
        }
    }
}
