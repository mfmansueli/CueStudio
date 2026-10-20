//
//  EyeContactHold.swift
//  Cue Studio
//

import Foundation

/// Why Eye Contact leaves a frame (or eases off): the frame keeps the eyes it was filmed with rather than guess.
nonisolated enum EyeContactHold: String, CaseIterable, Sendable {
    /// No face, or the landmarks unsure of it.
    case noFace
    /// Another person's face is nearly as large.
    case otherPeople
    /// The eyes are too small in the frame.
    case smallEyes
    /// A blink, or the eyes nearly closed.
    case blink
    /// The head is tilted or turned too far.
    case headTurned
    /// The eyes look at the lens already, up, far down or aside.
    case lookingAway
    /// The eyes are blurred by movement: there's no detail to move.
    case blurred
    /// This part of the recording isn't analyzed yet.
    case notAnalyzed
}
