//
//  IdeaSlot.swift
//  Cue Studio
//

import Foundation

/// One idea to be written: the way it looks at its topic and which topic it is about.
nonisolated struct IdeaSlot: Hashable, Sendable {
    var angle: IdeaAngle
    var topic: IdeaTopic
    /// What it is tied to besides (an occasion, a video they posted, a comment), when it is (`IdeaSignals.tie`).
    var tie: IdeaTie?
}
