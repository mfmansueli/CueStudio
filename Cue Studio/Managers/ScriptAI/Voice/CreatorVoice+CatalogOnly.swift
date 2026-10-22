//
//  CreatorVoice+CatalogOnly.swift
//  Cue Studio
//

import Foundation

nonisolated extension CreatorVoice {
    /// The voice without anything the creator typed: only what Cue offers (the tones, styles, topics and formats, the audience groups, the
    /// avoid rules it knows). For the one new attempt after the model refused a request with the creator's own words in it.
    var catalogOnly: CreatorVoice {
        var safe = self
        safe.phrases = []
        safe.openings = openings.filter { if case .known = VoiceChoiceCatalog.opening($0) { true } else { false } }
        safe.endings = endings.filter { if case .known = VoiceChoiceCatalog.ending($0) { true } else { false } }
        safe.avoid = avoid.filter { VoiceAvoidRule.rule(for: $0) != nil }
        safe.examples = []
        safe.approvedSamples = []
        safe.excerpts = []
        safe.customTags = []
        safe.audienceNote = nil
        safe.customRole = nil
        safe.credential = nil
        safe.topics = topics.compactMap { entry in
            if case .custom = entry.topic { return nil }
            return VoiceTopicEntry(topic: entry.topic, subtopics: entry.subtopics.filter { sub in entry.topic.suggestedSubtopics.contains { $0.id == sub } })
        }
        return safe
    }
}
