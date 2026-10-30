//
//  WritingArrival.swift
//  Cue Studio
//

import Foundation

/// A step of a pass's words arriving (`WritingProgressMeter.arrivals`): which pass, how far it had come, and when. Each is a spark from the
/// star of an Ultra AI script (`UltraWaitScene`).
nonisolated struct WritingArrival: Equatable, Sendable {
    /// Which pass, from 0.
    let pass: Int
    /// How far the pass had come, 0…1.
    let fraction: Double
    /// When, in the meter's seconds.
    let time: TimeInterval
}
