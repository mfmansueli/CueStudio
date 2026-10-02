//
//  VoiceSetupStep.swift
//  Cue Studio
//

import Foundation

/// The three things "Write in my voice" needs to know about a creator, asked in this order by the
/// short setup: what they make, who they talk to and how they talk. Each one is a field the AI
/// already reads (`CreatorVoice`): niches, vocabulary and "How I sound".
nonisolated enum VoiceSetupStep: String, Codable, CaseIterable, Identifiable, Sendable {
    /// "What do you create?": `CreatorProfile.niches`.
    case niche
    /// "Who do you talk to?": `CreatorProfile.vocabulary` (the words the audience understands).
    case audience
    /// "How do you talk?": `CreatorProfile.sounds`.
    case tone

    var id: String { rawValue }

    var question: String {
        switch self {
        case .niche: String(localized: "What do you create?")
        case .audience: String(localized: "Who do you talk to?")
        case .tone: String(localized: "How do you talk?")
        }
    }
}
