//
//  ExtractedSound.swift
//  Cue Studio
//

import Foundation

/// A sound Extract audio wrote into the edit's media (`EditMediaFiles`).
nonisolated struct ExtractedSound: Hashable, Sendable {
    let fileName: String
    /// Its length in seconds: the stretch taken, at the clip's speed.
    let duration: TimeInterval
}
