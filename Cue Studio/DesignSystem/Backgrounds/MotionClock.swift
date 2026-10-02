//
//  MotionClock.swift
//  Cue Studio
//

import Foundation

/// Keeps the last frame while paused, then resumes without counting time spent off screen. The
/// decorative backgrounds and the stars read their time from it, so they pause together.
struct MotionClock {
    private var accumulated: TimeInterval = 0
    private var startedAt: Date?

    func elapsed(at date: Date) -> TimeInterval {
        accumulated + (startedAt.map { max(0, date.timeIntervalSince($0)) } ?? 0)
    }

    mutating func setRunning(_ running: Bool, at date: Date) {
        if running {
            if startedAt == nil { startedAt = date }
        } else if startedAt != nil {
            accumulated = elapsed(at: date)
            startedAt = nil
        }
    }
}
