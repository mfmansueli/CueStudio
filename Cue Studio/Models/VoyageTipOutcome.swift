//
//  VoyageTipOutcome.swift
//  Cue Studio
//

import Foundation

/// What happened with a first voyage tip, or its step.
nonisolated enum VoyageTipOutcome: String, Sendable {
    /// The tip came into view (once per session and place).
    case shown
    /// Its button was tapped.
    case acted
    /// ✕ (back next session while the step is still ahead).
    case closed
    /// The step got done, wherever the creator did it.
    case stepDone
}
