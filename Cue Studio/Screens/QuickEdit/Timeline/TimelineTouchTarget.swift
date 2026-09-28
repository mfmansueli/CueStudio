//
//  TimelineTouchTarget.swift
//  Cue Studio
//

import Foundation

/// What a touch on the timeline takes hold of, decided where the finger lands and kept until it
/// lifts, so a drag meant for a handle never scrubs and a scrub never trims.
nonisolated enum TimelineTouchTarget: Equatable, Sendable {
    /// Trims.
    case handle(TrimHandle)
    /// Drags the playhead from where it is.
    case playhead
    /// Jumps the playhead to the finger and follows it; a tap also selects the piece there.
    case timeline
}
