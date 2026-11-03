//
//  CreatorProfile+Topics.swift
//  Cue Studio
//

import Foundation

nonisolated extension CreatorProfile {
    /// Every topic the creator holds, each a world in the universe (`TopicTaggingService`): Cue's themes, then the ones they typed.
    var topics: [VoiceTopicRef] {
        niches.map(VoiceTopicRef.niche) + customTopics.map(VoiceTopicRef.custom)
    }

    /// How many topics there are, of any kind: at most `VoiceLimits.topics`.
    var topicCount: Int { niches.count + customTopics.count }

    /// The subtopics kept under `topic` (up to `VoiceLimits.details`).
    func subtopics(of topic: VoiceTopicRef) -> [String] {
        topicDetails[topic.id] ?? []
    }

    /// Who is talking: the creator's choice, or what their kind of creator suggests ("I" with neither).
    var resolvedSpeaksAs: SpeaksAs {
        speaksAs ?? kind?.suggestedSpeaksAs ?? role?.suggestedSpeaksAs ?? .i
    }

    /// The creator's own kind out of the long list, when they picked one.
    var kind: CreatorKind? { CreatorKind.find(creatorKind) }

    /// How the Profile names the creator ("@ana · Lawyer"): what they typed, their kind, or their broad kind.
    var creatorTitle: String? { customRole ?? kind?.title ?? role?.creatorLabel }
}
