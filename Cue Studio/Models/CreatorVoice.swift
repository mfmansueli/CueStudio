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

    /// Who is talking: the creator's choice, or what their kind of creator suggests ("I" with neither).
    var resolvedSpeaksAs: SpeaksAs { speaksAs ?? role?.suggestedSpeaksAs ?? .i }
}
