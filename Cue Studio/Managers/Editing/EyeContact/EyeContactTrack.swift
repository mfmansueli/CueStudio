//
//  EyeContactTrack.swift
//  Cue Studio
//

import Foundation

/// Eye Contact for one recording of a built composition: its decisions (`EyeGazePlan`) at the edit's strength, looked up by the
/// moment of the recording a frame shows. Fixed when the composition is built, so a frame draws the same however often, and in
/// whatever order, it's asked for.
nonisolated struct EyeContactTrack: Sendable {
    let plan: EyeGazePlan
    let strength: Double

    /// What to draw on the frame of the recording shown at `time` (its own seconds); nil leaves it as filmed.
    func frame(at time: TimeInterval) -> EyeContactFrame? {
        plan.frame(at: time, strength: strength)
    }
}
