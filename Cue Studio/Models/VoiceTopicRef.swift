//
//  VoiceTopicRef.swift
//  Cue Studio
//

import Foundation

/// One topic as My Cue Voice sees it: one of the ten of the first flight, one only the voice offers, or one the creator typed. The three
/// kinds sit side by side in the answer (at most `VoiceLimits.topics` together) and each can carry up to `VoiceLimits.details` subtopics.
nonisolated enum VoiceTopicRef: Hashable, Identifiable, Sendable {
    case niche(Niche)
    case extra(VoiceTopic)
    case custom(String)

    /// The key subtopics are kept under (`CreatorProfile.topicDetails`): the topic's own id, or the typed name.
    var id: String {
        switch self {
        case .niche(let niche): niche.rawValue
        case .extra(let topic): topic.rawValue
        case .custom(let name): name
        }
    }

    /// The name the creator reads.
    var label: String {
        switch self {
        case .niche(let niche): niche.chipLabel
        case .extra(let topic): topic.label
        case .custom(let name): name
        }
    }

    /// The name the AI reads (what the creator typed stays as typed).
    var promptName: String {
        switch self {
        case .niche(let niche): niche.promptName
        case .extra(let topic): topic.promptName
        case .custom(let name): name
        }
    }

    /// The subtopics Cue suggests for it (a typed topic has none).
    var suggestedSubtopics: [VoiceOption] {
        switch self {
        case .niche(let niche): VoiceSubtopicCatalog.suggestions(for: niche)
        case .extra(let topic): VoiceSubtopicCatalog.suggestions(for: topic)
        case .custom: []
        }
    }
}
