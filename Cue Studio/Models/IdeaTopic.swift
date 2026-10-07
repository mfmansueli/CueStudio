//
//  IdeaTopic.swift
//  Cue Studio
//

import Foundation

/// A topic the creator makes videos about, as the ideas are asked for: the ten of the first flight have starter ideas of their own (`niche`), the ones only
/// My Cue Voice offers and the ones the creator typed have none, so only the model can suggest for them.
nonisolated struct IdeaTopic: Hashable, Codable, Sendable {
    /// What the model reads: what the creator typed stays as typed.
    var name: String
    /// What the creator reads.
    var label: String
    /// The topic when it is one of the first flight's.
    var niche: Niche?
    /// What the creator said they cover inside it ("Yoga & stretching", "Italian").
    var subtopics: [String] = []
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
