//
//  IdeaTopicFilter.swift
//  Cue Studio
//

import Foundation

/// What Find inspiration shows ideas about: all the creator's topics, or one of them (one of the first flight's, one only My Cue Voice
/// offers, or one they typed).
nonisolated enum IdeaTopicFilter: Hashable, Codable, Sendable {
    case all
    case topic(IdeaTopic)

    /// Whether `idea` is about what the filter shows.
    func includes(_ idea: ThemeIdea) -> Bool {
        switch self {
        case .all:
            true
        case .topic(let topic):
            if let topicName = idea.topic { topicName == topic.label || topicName == topic.name } else { topic.niche == idea.niche }
        }
    }
}
