//
//  GenerationProgress.swift
//  Cue Studio
//

import Foundation

/// What a request to the model has done so far, for the watchdog that gives up on it (`GenerationDeadlines`). On the main actor, like the request itself.
@MainActor
final class GenerationProgress {
    private let clock = ContinuousClock()
    private let started: ContinuousClock.Instant
    private var lastProgress: ContinuousClock.Instant
    private(set) var hasResponded = false
    /// The watchdog gave up on the request.
    private(set) var didStall = false

    init() {
        started = clock.now
        lastProgress = started
    }

    /// Words arrived.
    func noteProgress() {
        hasResponded = true
        lastProgress = clock.now
    }

    /// Checks the request against `deadlines`; true (and remembered) when it should be given up on.
    func checkStalled(against deadlines: GenerationDeadlines) -> Bool {
        let now = clock.now
        guard deadlines.isStalled(elapsed: started.duration(to: now), sinceProgress: lastProgress.duration(to: now), hasResponded: hasResponded) else {
            return false
        }
        didStall = true
        return true
    }
}
