//
//  EyeContactFrame.swift
//  Cue Studio
//

import Foundation

/// What Eye Contact does to one frame of a recording: its two eyes (smoothed over time, on the top-left unit square of the upright
/// frame) and how far up to turn them, in degrees.
nonisolated struct EyeContactFrame: Hashable, Sendable {
    /// The eye on the image's left, then the one on its right.
    var eyes: [EyeShape]
    /// How far up, above 0 (the measured angle × how much of it this frame gets × the creator's strength).
    var degrees: Double
}
