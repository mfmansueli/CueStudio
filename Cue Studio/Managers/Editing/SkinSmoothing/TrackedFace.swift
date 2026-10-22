//
//  TrackedFace.swift
//  Cue Studio
//

import CoreGraphics
import Foundation

/// A face that stays the same face from one detection to the next, and how much of the smoothing it has now.
nonisolated struct TrackedFace: Hashable, Sendable {
    var id: Int
    var landmarks: FaceLandmarks
    /// 0…1: a face that has just come into the shot fades in, one that stops being found fades out, so smoothing never switches on or off in one frame.
    var presence: Double
}
