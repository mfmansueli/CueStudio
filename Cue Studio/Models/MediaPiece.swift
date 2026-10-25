//
//  MediaPiece.swift
//  Cue Studio
//

import Foundation

/// A stretch of the edit where a photo or video laid over the take shows without a break, and the second of its file that
/// plays at the stretch's start (a video plays on from there at its own speed; a photo ignores it). One media can show in
/// several pieces: what the edit cut out of the speech under it is cut out of it too (`MediaOverlay.pieces`).
nonisolated struct MediaPiece: Hashable, Sendable {
    /// Edited seconds it shows.
    var edited: TimeSpan
    /// Seconds of the file shown at `edited.start`.
    var fileStart: TimeInterval

    var fileEnd: TimeInterval { fileStart + edited.duration }
}
