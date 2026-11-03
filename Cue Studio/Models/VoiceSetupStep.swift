//
//  VoiceSetupStep.swift
//  Cue Studio
//

import Foundation

/// The three things "Write in my voice" needs to know about a creator, asked in this order by the
/// short setup: what they make, who they talk to and how they talk. Each one is a field the AI
/// already reads (`CreatorVoice`): niches, vocabulary and "How I sound".
nonisolated enum VoiceSetupStep: String, Codable, CaseIterable, Identifiable, Sendable {
    /// "What kind of creator are you?": `CreatorProfile.role`. The first question, and the only one
    /// the AI can do without: it is asked, never required.
    case role
    /// "How should scripts talk about you?": I or we, the grammar and a credential (`VoiceSpeechField`), asked right after the kind of creator
    /// (the owner, 03/11/2026: one screen held five questions). Optional: each has a default or can stay unsaid.
    case speech
    /// "What do you create?": `CreatorProfile.niches`.
    case niche
    /// "Who do you talk to?": `CreatorProfile.vocabulary` (the words the audience understands).
    case audience
    /// "How do you talk?": `CreatorProfile.sounds`.
    case tone

    var id: String { rawValue }

    /// What "Write in my voice" can't be used without. The kind of creator helps and is optional.
    var isRequired: Bool { self != .role && self != .speech }

    var question: String {
        switch self {
        case .role: String(localized: "What kind of creator are you?")
        case .speech: String(localized: "How should scripts talk about you?")
        case .niche: String(localized: "What do you create?")
        case .audience: String(localized: "Who do you talk to?")
        case .tone: String(localized: "How do you talk?")
        }
    }
}
