//
//  VoiceTopicRef.swift
//  Cue Studio
//

import Foundation

/// One topic as My Cue Voice sees it: one of Cue's themes or one the creator typed. They sit side by side in the answer (at most
/// `VoiceLimits.topics` together) and each can carry up to `VoiceLimits.details` subtopics.
nonisolated enum VoiceTopicRef: Hashable, Identifiable, Sendable {
    case niche(Niche)
    case custom(String)

    /// The key subtopics are kept under (`CreatorProfile.topicDetails`): the theme's own id, or the typed name.
    var id: String {
        switch self {
        case .niche(let niche): niche.rawValue
        case .custom(let name): name
        }
    }

    /// The name the creator reads.
    var label: String {
        switch self {
        case .niche(let niche): niche.chipLabel
        case .custom(let name): name
        }
    }

    /// The name the AI reads (what the creator typed stays as typed).
    var promptName: String {
        switch self {
        case .niche(let niche): niche.promptName
        case .custom(let name): name
        }
    }

    /// The subtopics Cue suggests for it (a typed topic has none).
    var suggestedSubtopics: [VoiceOption] {
        switch self {
        case .niche(let niche): VoiceSubtopicCatalog.suggestions(for: niche)
        case .custom: []
        }
    }
}
