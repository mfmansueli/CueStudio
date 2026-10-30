//
//  WritingPass.swift
//  Cue Studio
//

import Foundation

/// One pass of a writer that works in several (Ultra AI: the draft, its claims checked, the polish in the creator's voice), for the star's
/// arcs while it waits (`UltraPassOrbit`): which pass it is, of how many, and how far its words have come.
nonisolated struct WritingPass: Equatable, Sendable {
    /// Which pass, from 0, of `count`.
    let index: Int
    let count: Int
    /// When it started, in the meter's seconds.
    let startedAt: TimeInterval
    /// How far its words have come, 0…1.
    var fraction = 0.0

    /// How far the pass looks at `time`: a creep that slows toward a third of it (the model thinks before its words come, so the arc is
    /// never still), and its words over the rest.
    func shown(at time: TimeInterval) -> Double {
        let creep = Self.creepCeiling * (1 - exp(-max(0, time - startedAt) / Self.creepTime))
        return min(1, creep + (1 - creep) * fraction)
    }

    /// The most the creep shows, and how fast it gets near it (seconds).
    static let creepCeiling = 0.35
    static let creepTime = 7.0
}
