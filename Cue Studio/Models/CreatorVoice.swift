//
//  CreatorVoice.swift
//  Cue Studio
//

import Foundation

/// How the creator talks, as the AI needs it: one profile for every platform. Built from
/// `CreatorProfile` and sent in the model's instructions when "Write in my voice" is on.
nonisolated struct CreatorVoice: Hashable, Sendable {
    var sounds: [VoiceSound]
    var phrases: [String]
    /// Nil when the creator hasn't picked one.
    var vocabulary: Vocabulary?
    var styles: [VoiceStyle]
    var niches: [Niche]
    /// Who is talking; nil when the creator didn't say.
    var role: CreatorRole?
    // The Personality and Proof layers (v29).
    var openings: [String] = []
    var endings: [String] = []
    var formats: [ScriptType] = []
    var swearing: Swearing?
    // What the question bank added (v30 · 08): how they come across, what to avoid, where and how long they post.
    var style = VoiceDelivery()
    var avoid: [String] = []
    var reach = VoiceReach()
    var audienceLevel: AudienceLevel?
    var examples: [VoiceExample] = []
    var customTags: [String] = []
    // My Cue Voice for Apple Intelligence (v2).
    /// Every topic, in the order the creator holds them, with its subtopics: the ten of the first flight, the ones only the voice offers
    /// and the ones they typed (`niches` is the first kind alone).
    var topics: [VoiceTopicEntry] = []
    var audienceGroup: AudienceGroup?
    var audienceNote: String?
    var watchReasons: [WatchReason] = []
    var contentGoals: [ContentGoal] = []
    var customRole: String?
    var credential: String?
    /// "I" or "we" as the creator chose; nil when they didn't (`resolvedSpeaksAs`).
    var speaksAs: SpeaksAs?
    /// Scripts the creator approved with "Sounds like me", oldest first.
    var approvedSamples: [VoiceExample] = []
    // What the creator imported ("Import my writing").
    /// The excerpts of their writing the request is sent as examples: a request narrows the library to the ones that fit it
    /// (`ExcerptRetriever`).
    var excerpts: [VoiceExcerpt] = []
    /// How their writing measured; nil when nothing was imported.
    var fingerprint: VoiceFingerprint?

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

    /// Who is talking: the creator's choice, or what their kind of creator suggests ("I" with neither).
    var resolvedSpeaksAs: SpeaksAs { speaksAs ?? role?.suggestedSpeaksAs ?? .i }

    /// "Casual · Confident · “Hey fam”", the one-line summary under "Write in my voice".
    var summary: String {
        let sound = sounds.prefix(2).map(\.label)
        let phrase = phrases.first.map { ["“\($0)”"] } ?? []
        return (sound + phrase).joined(separator: " · ")
    }

    /// A line in the creator's voice for the "Sounds like you" preview. Deterministic, so the
    /// preview changes only when the voice does.
    var sampleLine: String {
        let opening: String = switch sounds.first {
        case .energetic: String(localized: "Okay, this is huge!")
        case .professional: String(localized: "Here's what most people miss.")
        case .funny: String(localized: "I did something ridiculous so you don't have to.")
        case .educational: String(localized: "Let me explain this in 30 seconds.")
        case .confident: String(localized: "I'll say it: you don't need more gear.")
        case .warmCalm: String(localized: "Let's slow down for a second.")
        case .dry: String(localized: "Great. Another thing nobody asked for.")
        case .casual, nil: String(localized: "So, real quick.")
        }
        let body: String = if styles.contains(.storytelling) {
            String(localized: "Last week I filmed five videos in one afternoon.")
        } else if styles.contains(.opinionDriven) {
            String(localized: "Most creators overthink the camera and underthink the first line.")
        } else {
            String(localized: "Your first line matters more than your camera.")
        }
        let ending: String = switch vocabulary {
        case .genZ?: " " + String(localized: "No cap.")
        case .technical?: " " + String(localized: "The hook sets retention for the whole video.")
        case .professional?: " " + String(localized: "That is what drives retention.")
        case .simple?, nil: ""
        }
        let greeting = phrases.first.map { "\($0)! " } ?? ""
        return greeting + opening + " " + body + ending
    }
}
