//
//  PrompterLaunch.swift
//  Cue Studio
//

import Foundation

/// Opens the prompter full screen. A nil script records freestyle.
struct PrompterLaunch: Identifiable, Hashable {
    let id = UUID()
    var scriptID: UUID?
    var mode: PrompterMode
    /// When set, the prompter opens on this take's review instead of the camera.
    var reviewTakeID: UUID?
    /// The first flight's practice run: the prompter over the front camera, not recording.
    var isPractice = false
    /// What the review does as it opens: the Takes tab's swipe and peek go straight to Share or Edit.
    var reviewAction: ReviewLaunchAction?
}

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
    /// Opens "Pick your best take" (6.1): after a stop that leaves two or more takes and no ★.
    case pickBest
}
