//
//  RecordingBackground.swift
//  Cue Studio
//

import Foundation

/// A recording's background effect: the take's (`sourceID` nil) or another recording's of a
/// montage. Every section of that recording gets it.
nonisolated struct RecordingBackground: Codable, Hashable, Sendable {
    var sourceID: UUID?
    var effect: BackgroundEffect
}
