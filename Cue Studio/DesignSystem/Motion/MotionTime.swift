//
//  MotionTime.swift
//  Cue Studio
//

import Foundation

/// The two clocks of a scene drawn from a board's motion.
nonisolated struct MotionTime: Sendable {
    /// Seconds of the board's timeline, held at the second the scene is complete: the choreography plays once and stays.
    let clock: Double
    /// Seconds since the scene appeared, never held: what ambient loops (a halo breathing, an orbit turning) run on. Zero when the scene is
    /// still (Reduce Motion, a frozen picture).
    let ambient: Double
    /// The scene is at rest: nothing moves any more.
    let isStill: Bool
    /// The moment being drawn, for things that start at a tap and run their own time from there.
    var now = Date.now
}
