//
//  XCUIElement+Waiting.swift
//  Cue StudioUITests
//

import XCTest

/// Waits that look at once and then every 0.1 s. XCTest's `waitForExistence` / `waitForNonExistence` take their first look
/// only after a second, even when the element is already there: with ~2,000 waits that was a third of the UI tests' time.
/// What only turns up while waiting came with a transition, and a tap the moment it appears can land before the screen takes
/// touches: the wait goes on 0.3 s more and until it stops moving.
@MainActor
extension XCUIElement {
    /// `waitForExistence(timeout:)` without its one-second first look.
    func exists(within timeout: TimeInterval) -> Bool {
        if exists { return true }
        guard poll(timeout, until: { exists }) else { return false }
        Thread.sleep(forTimeInterval: 0.3)
        waitUntilStill()
        return true
    }

    /// `waitForNonExistence(timeout:)` without its one-second first look.
    func isGone(within timeout: TimeInterval) -> Bool {
        !exists || poll(timeout, until: { !exists })
    }

    /// Until the element is in the same place twice in a row, 0.1 s apart (at most a second): a sheet sliding up, a tip
    /// growing in, a list still gliding after a swipe.
    func waitUntilStill() {
        let deadline = Date().addingTimeInterval(1)
        var last = frame
        repeat {
            Thread.sleep(forTimeInterval: 0.1)
            let now = frame
            if now == last { return }
            last = now
        } while Date() < deadline
    }

    /// Every 0.1 s until `condition` holds or `timeout` runs out.
    private func poll(_ timeout: TimeInterval, until condition: () -> Bool) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        repeat {
            guard Date() < deadline else { return false }
            Thread.sleep(forTimeInterval: 0.1)
        } while !condition()
        return true
    }
}
