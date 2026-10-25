//
//  RecordingFraming.swift
//  Cue Studio
//

import Foundation

/// How one recording of the main video sits in its split-screen area: the take's (`sourceID` nil) or another recording's
/// of a montage. Every clip of that recording shows the same way, so the person doesn't jump when the support changes or at a
/// cut, while two people filmed apart each keep their own framing.
nonisolated struct RecordingFraming: Codable, Hashable, Sendable {
    var sourceID: UUID?
    var framing: AreaFraming
}
