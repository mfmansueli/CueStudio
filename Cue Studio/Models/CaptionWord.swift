//
//  CaptionWord.swift
//  Cue Studio
//

import Foundation

/// One word of a caption and when it is said, in seconds of the recording.
nonisolated struct CaptionWord: Codable, Hashable, Sendable {
    var text: String
    var start: TimeInterval
    var end: TimeInterval
    /// No measured word boundary: the recognizer timed several words as one stretch (each keeps
    /// that same segment span), or the word was typed in a correction. Shows a static line, never
    /// pretends to light the word as it is said.
    var isEstimated: Bool

    init(text: String, start: TimeInterval, end: TimeInterval, isEstimated: Bool = false) {
        self.text = text
        self.start = start
        self.end = max(start, end)
        self.isEstimated = isEstimated
    }
}
