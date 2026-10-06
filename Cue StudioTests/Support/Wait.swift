//
//  Wait.swift
//  Cue StudioTests
//

import Testing

/// Waiting for work a test started (a view model's task, a timer, a player) to show its result.
enum Wait {
    /// Waits until `condition` holds. A few turns of the caller's actor are usually enough, so it yields first; then it
    /// checks on the clock up to `timeout`, far beyond any wait under test, so a busy run (the whole suite in parallel) only
    /// makes a test slower, never wrong. A condition that never comes true is recorded where the test waited.
    ///
    /// It runs on the caller's actor (`nonisolated(nonsending)`), so `condition` can read `@MainActor` state.
    @discardableResult
    nonisolated(nonsending) static func until(
        timeout: Duration = .seconds(30),
        sourceLocation: SourceLocation = #_sourceLocation,
        _ condition: () -> Bool
    ) async -> Bool {
        for _ in 0..<200 {
            if condition() { return true }
            await Task.yield()
        }
        let deadline = ContinuousClock.now + timeout
        while ContinuousClock.now < deadline, !Task.isCancelled {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        if condition() { return true }
        Issue.record("Waited \(timeout) and the condition never came true", sourceLocation: sourceLocation)
        return false
    }
}
