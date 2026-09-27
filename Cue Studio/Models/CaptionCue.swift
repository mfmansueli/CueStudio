//
//  CaptionCue.swift
//  Cue Studio
//

import Foundation

/// One caption on screen: a few words from the script, timed to when they are said.
nonisolated struct CaptionCue: Codable, Hashable, Sendable {
    var text: String
    /// Seconds in the original recording.
    var start: TimeInterval
    var end: TimeInterval
}
