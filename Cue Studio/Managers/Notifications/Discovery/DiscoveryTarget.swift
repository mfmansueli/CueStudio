//
//  DiscoveryTarget.swift
//  Cue Studio
//

import Foundation

/// Where a tool is introduced: a place in the app, or a real object of the creator's that suits it (a script ready to read, a take the
/// tool can work on). Without a suitable object the tool isn't offered.
nonisolated enum DiscoveryTarget: Hashable, Sendable {
    /// What a take needs to suit a tool.
    enum TakeNeed: Hashable, Sendable {
        /// Any take of a few seconds or more.
        case any
        /// Long enough to have pauses, Clean Up not run, its language heard on this iPhone.
        case cleanUp
        /// No captions, its language heard on this iPhone.
        case withoutCaptions
        /// Captions, and a translation from its language exists.
        case translatableCaptions
        /// Not exported yet (a video still being made).
        case unfinished
    }

    /// A place, always the same.
    case place(NotificationDestination)
    /// A finished script with no take, whose language Voice Following hears.
    case readyScript
    /// A take that suits the tool, opened on `tool` in Quick edit.
    case take(TakeNeed, tool: EditorTool)
    /// A take or script made for TikTok, Reels, Shorts or Stories (their buttons cover the edges).
    case socialVideo(NotificationDestination)
}
