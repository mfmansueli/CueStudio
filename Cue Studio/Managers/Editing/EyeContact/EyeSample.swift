//
//  EyeSample.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// What was found in one frame of a recording for Eye Contact: the main person's face and eyes, or nothing usable.
nonisolated struct EyeSample: Hashable, Sendable {
    /// The frame's presentation time in the recording, in seconds.
    var time: TimeInterval
    /// The main person's face; nil when there was none (or its eyes couldn't be placed).
    var face: Face?

    struct Face: Hashable, Sendable {
        /// The face's box, on the top-left unit square of the upright frame.
        var box: CGRect
        /// The face landmarks' confidence that this is a face, 0 to 1.
        var confidence: Double
        /// Someone else's face is nearly as large: Eye Contact pauses rather than guess who is speaking.
        var crowded: Bool
        /// The eye on the image's left, then the one on its right.
        var eyes: [EyeShape]
        /// How sharp the eyes are (the variance of the Laplacian of their luma, on the landmarks' 256-pixel face crop): only
        /// compared with the same recording's other frames, where motion blur shows as a drop.
        var sharpness: Double = 0
    }
}
