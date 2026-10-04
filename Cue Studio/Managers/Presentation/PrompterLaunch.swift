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
    /// Opens "Share to".
    case share
    /// Opens Quick edit.
    case edit
}
