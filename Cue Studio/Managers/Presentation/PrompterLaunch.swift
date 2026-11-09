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
    /// The network the recorder opens on when it was asked for one (a Retake of a video recorded for Reels records for Reels); nil: the
    /// script's, or the creator's default in Freestyle.
    var platform: Platform?
    /// When set, the prompter opens on this take's review instead of the camera.
    var reviewTakeID: UUID?
    /// The first flight's practice run: the prompter over the front camera, not recording.
    var isPractice = false
    /// What the review does as it opens: the Takes tab's swipe and peek go straight to Share or Edit.
    var reviewAction: ReviewLaunchAction?
}
