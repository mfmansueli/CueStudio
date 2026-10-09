//
//  NotificationFacts.swift
//  Cue Studio
//

import Foundation

/// What the rules read: the projects, the tools used and what this iPhone can do, taken from the app's services at one moment
/// (`AppNotificationFacts`). A value, so the campaign and discovery rules are pure and tested with made-up facts. Titles are here for the
/// creator's own screens and for previews they allowed; script text never is.
nonisolated struct NotificationFacts: Sendable {
    struct ScriptFact: Hashable, Sendable {
        var id: UUID
        var title: String
        var state: ScriptState
        var wordCount: Int
        var createdAt: Date
        var updatedAt: Date
        var language: CueLanguage?
        var platform: Platform
    }

    struct TakeFact: Hashable, Sendable {
        var id: UUID
        var scriptID: UUID?
        var title: String
        var recordedAt: Date
        var duration: TimeInterval
        /// The stage of the video it belongs to (`TakeStage`).
        var stage: TakeStage
        var isExported: Bool
        /// Its video (the takes of its script) has a take exported.
        var videoExported: Bool
        var platform: Platform?
        var language: CueLanguage?
        var hasCaptions: Bool
        var cleanUpAnalyzed: Bool
        /// The tools its edit shows were used (`FeatureAdoption.tools(in:)`).
        var toolsUsed: Set<FeatureID>
    }

    struct QueueFact: Hashable, Sendable {
        var takeID: UUID
        var title: String
        /// Networks still waiting, pending first, then the ones left for later.
        var waiting: [ShareDestination]
        var updatedAt: Date?
    }

    struct NoteFact: Hashable, Sendable {
        var id: UUID
        var createdAt: Date
    }

    /// An idea the model wrote and Cue keeps, not shown yet.
    struct IdeaFact: Hashable, Sendable {
        var key: String
        /// Cue's own name for its topic (never one the creator typed), for previews they allowed.
        var topicLabel: String?
    }

    struct Capabilities: Hashable, Sendable {
        /// Apple Intelligence is on in Cue and writes on this iPhone.
        var aiWriting = false
        /// Languages Voice Following can listen in (now or after a download).
        var voiceFollowing: Set<CueLanguage> = []
        /// Languages captions and Clean Up can hear.
        var captions: Set<CueLanguage> = []
        /// Languages whose captions can be translated into at least one other.
        var captionTranslation: Set<CueLanguage> = []
        /// Person segmentation for backgrounds works on this iPhone.
        var backgrounds = false
    }

    struct Profile: Hashable, Sendable {
        var hasTopics = false
        /// Any Essentials answer (My Cue Voice is on in writing from there).
        var voiceConfigured = false
        var hasImportedWriting = false
    }

    var now: Date
    var scripts: [ScriptFact] = []
    var takes: [TakeFact] = []
    var queues: [QueueFact] = []
    var notes: [NoteFact] = []
    var ideas: [IdeaFact] = []
    var capabilities = Capabilities()
    var profile = Profile()
    /// Tools seen used for real, from what is saved and from events (`FeatureAdoption`).
    var adopted: Set<FeatureID> = []
    /// The prompter scrolls at a set speed (Steady), not with the voice.
    var prompterIsSteady = true
    /// Videos shared to a network, as the creator confirmed them (Your universe).
    var sharedVideos = 0
    /// The year whose review is ready to watch (December onwards, three videos at least), when there is one.
    var yearReviewReady: Int?
    var appVersion = "1.0"
    /// When the creator last worked in Cue.
    var lastActivity: Date?

    var hasRecorded: Bool { !takes.isEmpty }

    func script(_ id: UUID?) -> ScriptFact? { id.flatMap { id in scripts.first { $0.id == id } } }

    func take(_ id: UUID) -> TakeFact? { takes.first { $0.id == id } }

    func takes(of scriptID: UUID) -> [TakeFact] { takes.filter { $0.scriptID == scriptID } }
}
