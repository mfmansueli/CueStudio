//
//  ReviewLaunchAction.swift
//  Cue Studio
//

import Foundation

/// A step the take review starts on its own.
enum ReviewLaunchAction: Hashable {
    /// Opens "Share to universe" (the networks).
    case share
    /// "Continue posting": the next network of a queue that was left.
    case continueQueue
    /// "POST TO LINKEDIN LATER": that network, from a queue that was left.
    case postLater(ShareDestination)
    /// Opens Quick edit.
    case edit
    /// Opens Quick edit on one tool, without running it (a notification's "Try it").
    case editTool(EditorTool)
    /// Opens "Pick your best take" (6.1): after a stop that leaves two or more takes and no ★.
    case pickBest
}
