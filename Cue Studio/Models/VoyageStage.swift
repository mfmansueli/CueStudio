//
//  VoyageStage.swift
//  Cue Studio
//

import Foundation

/// Where the first voyage is for this creator.
nonisolated enum VoyageStage: String, Codable, Sendable {
    /// The next step's tip shows where it helps.
    case active
    /// "Hide guide": nothing shows until it is brought back (Settings › Personalize).
    case hidden
    /// The first video was shared and that was said ("✓ Your first star is out there"): it never shows again.
    case finished
    /// The creator had shared a video before the guide existed: they never see it.
    case notNeeded
}
