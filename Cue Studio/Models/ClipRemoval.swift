//
//  ClipRemoval.swift
//  Cue Studio
//

import Foundation

/// A clip deleted from the video (`TakeEdit.removingClip`): the edit without it, and how many of the layers that showed only on
/// it went with it, for the toast that says so ("Clip 2 deleted, with 1 text and 2 sounds" · Undo).
nonisolated struct ClipRemoval: Sendable {
    var edit: TakeEdit
    var texts = 0
    var photos = 0
    var videos = 0
    var voiceOvers = 0
    /// Sound effects and extracted sounds put on its moments.
    var sounds = 0

    /// Nothing went with it.
    var isAlone: Bool { texts + photos + videos + voiceOvers + sounds == 0 }
}
