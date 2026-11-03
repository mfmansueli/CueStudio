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
    /// Who is talking; nil when the creator didn't say.
    var role: CreatorRole?
    /// Who is talking, in the creator's own kind out of the long list (`CreatorKind`, its id): said in place of `role` when there is one.
    var creatorKind: String?
    // The Personality and Proof layers (v29).
    var openings: [String] = []
    var endings: [String] = []
    /// Cue's openings and endings they never use (the owner's item 5): "Never open with…", "Never end by…".
    var neverOpenings: [String] = []
    var neverEndings: [String] = []
    /// True moments they told (`VoiceStory`; the owner's item 9): the first `VoiceStory.perRequest` are read.
    var stories: [VoiceStory] = []
    var formats: [ScriptType] = []
    var swearing: Swearing?
    // What the question bank added (v30 · 08): how they come across, what to avoid, where and how long they post.
    var style = VoiceDelivery()
    var avoid: [String] = []
    var reach = VoiceReach()
    var audienceLevel: AudienceLevel?
    var examples: [VoiceExample] = []
    var customTags: [String] = []
    /// Formats they typed (`CreatorProfile.customFormats`).
    var customFormats: [String] = []
    // My Cue Voice for Apple Intelligence (v2).
    /// Every topic, in the order the creator holds them, with its subtopics: the ten of the first flight, the ones only the voice offers
    /// and the ones they typed.
    var topics: [VoiceTopicEntry] = []
    var audienceGroup: AudienceGroup?
    var audienceNote: String?
    var watchReasons: [WatchReason] = []
    var contentGoals: [ContentGoal] = []
    var customRole: String?
    var credential: String?
    /// "I" or "we" as the creator chose; nil when they didn't (`resolvedSpeaksAs`).
    var speaksAs: SpeaksAs?
    /// Gender agreement and the form of address (`VoiceAgreement`, B8): a rule, kept by `restrictionsOnly`.
    var agreement = VoiceAgreement()
    /// Scripts the creator approved with "Sounds like me", oldest first.
    var approvedSamples: [VoiceExample] = []
    // What the creator imported ("Import my writing").
    /// The excerpts of their writing the request is sent as examples: a request narrows the library to the ones that fit it
    /// (`ExcerptRetriever`).
    var excerpts: [VoiceExcerpt] = []
    /// How their writing measured; nil when nothing was imported.
    var fingerprint: VoiceFingerprint?

    /// Who is talking: the creator's choice, or what their kind of creator suggests ("I" with neither).
    var resolvedSpeaksAs: SpeaksAs { speaksAs ?? CreatorKind.find(creatorKind)?.suggestedSpeaksAs ?? role?.suggestedSpeaksAs ?? .i }

    /// Who they are, for the AI: what they typed, their kind out of the long list, or their broad kind.
    var whoTheyAre: String? {
        customRole ?? CreatorKind.find(creatorKind)?.promptName ?? role?.promptName
    }
}
