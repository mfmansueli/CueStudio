//
//  AmbientTime.swift
//  Cue Studio
//

import Foundation

/// The moment an ambient loop draws (`AmbientTimeline`).
nonisolated struct AmbientTime: Sendable {
    /// Seconds the loop has been running: they stop while it is off screen, scrolled away or the app is not in front, so coming back it goes on
    /// from the same frame. Zero with Reduce Motion.
    let seconds: TimeInterval
    /// The moment being drawn, for what runs on its own time (since a tap, since a pick).
    let date: Date
}
