//
//  CreatorProfile+Topics.swift
//  Cue Studio
//

import Foundation

nonisolated extension CreatorProfile {
    /// Every topic the creator holds: the ten of the first flight, then the ones only My Cue Voice offers, then the ones they typed.
    /// Only the first and the last make worlds in the universe (`TopicTaggingService`).
    var topics: [VoiceTopicRef] {
        niches.map(VoiceTopicRef.niche) + voiceTopics.map(VoiceTopicRef.extra) + customTopics.map(VoiceTopicRef.custom)
    }

    /// How many topics there are, of any kind: at most `VoiceLimits.topics`.
    var topicCount: Int { niches.count + voiceTopics.count + customTopics.count }

    /// The subtopics kept under `topic` (up to `VoiceLimits.details`).
    func subtopics(of topic: VoiceTopicRef) -> [String] {
        topicDetails[topic.id] ?? []
    }

    /// Who is talking: the creator's choice, or what their kind of creator suggests ("I" with neither).
    var resolvedSpeaksAs: SpeaksAs {
        speaksAs ?? role?.suggestedSpeaksAs ?? .i
    }
}
