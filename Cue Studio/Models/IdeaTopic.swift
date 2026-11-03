//
//  IdeaTopic.swift
//  Cue Studio
//

import Foundation

/// A topic the creator makes videos about, as the ideas are asked for: one of Cue's themes (`niche`, most with starter ideas of their own) or one
/// the creator typed, with what they cover inside it.
nonisolated struct IdeaTopic: Hashable, Codable, Sendable {
    /// What the model reads: what the creator typed stays as typed.
    var name: String
    /// What the creator reads.
    var label: String
    /// The topic when it is one of Cue's themes.
    var niche: Niche?
    /// What the creator said they cover inside it ("Yoga & stretching", "Italian").
    var subtopics: [String] = []
}

extension IdeaTopic {
    /// What ideas are about until the creator chooses a topic: Lifestyle, as the starter ideas are.
    static let lifestyle = IdeaTopic(name: Niche.lifestyle.promptName, label: Niche.lifestyle.label, niche: .lifestyle)
}

extension CreatorProfile {
    /// Every topic the creator holds, with their subtopics, in the order they hold them; empty until they choose.
    var ideaTopics: [IdeaTopic] {
        topics.map { topic in
            var niche: Niche?
            if case .niche(let found) = topic { niche = found }
            return IdeaTopic(name: topic.promptName, label: topic.label, niche: niche, subtopics: subtopics(of: topic))
        }
    }
}
