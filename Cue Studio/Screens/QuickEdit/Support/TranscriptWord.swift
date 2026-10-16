//
//  TranscriptWord.swift
//  Cue Studio
//

import Foundation

/// A word of what was said, as Edit by text lists it: its recording and seconds there, where it plays in the edit, and whether
/// it was cut. A word in a copied clip is listed again, under that clip.
struct TranscriptWord: Identifiable, Hashable {
    /// Unique in the list: the clip it plays in and its place in its recording's transcript.
    let id: String
    let text: String
    /// The recording (nil: the take).
    let sourceID: UUID?
    /// Seconds of that recording.
    let span: TimeSpan
    /// Its place in that recording's transcript.
    let index: Int
    /// The clip it plays in; nil for a word that was cut.
    let segmentID: UUID?
    /// Edited seconds where it plays; nil for a word that was cut.
    let editedStart: TimeInterval?

    var isRemoved: Bool { editedStart == nil }
}
