//
//  VoyageStage.swift
//  Cue Studio
//

import Foundation

/// Where the first voyage is for this creator.
nonisolated enum VoyageStage: String, Codable, Sendable {
    /// The card shows the next step (or, once the first video is shared, that the voyage is complete).
    case active
    /// "Hide guide": nothing shows until it is brought back (Settings › Personalize).
    case hidden
    /// Complete, and the creator closed the card: it never shows again.
    case finished
    /// The creator had shared a video before the guide existed: they never see it.
    case notNeeded
}
