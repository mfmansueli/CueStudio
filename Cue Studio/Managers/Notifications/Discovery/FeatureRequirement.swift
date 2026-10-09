//
//  FeatureRequirement.swift
//  Cue Studio
//

import Foundation

/// A condition a tool needs before Cue introduces it: what this iPhone can do, and what the creator has done (a tool is only offered
/// where it fits their activity). Checked against `NotificationFacts` by `DiscoveryRules`.
nonisolated enum FeatureRequirement: Hashable, Sendable {
    /// Apple Intelligence is on in Cue and writes on this iPhone.
    case appleIntelligence
    /// At least this many scripts.
    case scripts(Int)
    /// At least one take.
    case recorded
    /// At least one video exported (a finished video).
    case finishedVideo
    /// My Cue Voice has no answer yet.
    case voiceNotConfigured
    /// My Cue Voice has an Essentials answer.
    case voiceConfigured
    /// Nothing imported for the voice yet.
    case notImported
    /// The creator has topics.
    case topics
    /// The prompter scrolls at a set speed.
    case steadyPrompter
    /// Person segmentation runs on this iPhone.
    case backgrounds
    /// At least this many videos shared.
    case sharedVideos(Int)
}
