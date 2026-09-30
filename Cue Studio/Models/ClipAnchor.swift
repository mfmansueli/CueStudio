//
//  ClipAnchor.swift
//  Cue Studio
//

import Foundation

/// A piece of an arranged edit something is pinned to (a text, a photo or video, a voice-over):
/// it moves with the piece, and a copy of the piece gets its own copy. The recording's seconds it
/// is pinned to are kept with the thing itself.
nonisolated struct ClipAnchor: Codable, Hashable, Sendable {
    /// The piece (`EditSegment.id`).
    var segmentID: UUID
    /// The recording the piece plays (nil: the take itself).
    var sourceID: UUID?
}
