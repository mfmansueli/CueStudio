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

    /// An `XCTNSPredicateExpectation` on the element (`label CONTAINS …`, `value == …`, `isSelected == true`) without its
    /// one-second first look.
    func matches(_ predicate: NSPredicate, within timeout: TimeInterval) -> Bool {
        predicate.evaluate(with: self) || poll(timeout, until: { predicate.evaluate(with: self) })
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

    /// A menu's item, tapped once it stops moving, until `result` (what it opens) shows. A tap while the menu was still opening is
    /// lost (the menu stays open, the item with it) and the item is tapped again; never once the item has gone or `result` is there:
    /// what it opened then sits where the item was (a second tap closed Script details from its ✕, 30/10/2026). On a loaded Simulator
    /// the script page's ••• menu, open and still, has also let both taps go by (two Fulls, 30/10/2026): then it is closed with a tap
    /// beside it and opened again from `menu`, as a person would.
    func tapMenuItem(opening result: XCUIElement, reopening menu: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        for attempt in 0..<2 {
            if attempt > 0 {
                XCUIApplication().coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.97)).tap()
                guard isGone(within: 3) else { break }
                menu.tap()
                guard exists(within: 5) else { break }
            }
            waitUntilStill()
            tap()
            let deadline = Date().addingTimeInterval(3)
            while !result.exists, exists, Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
            if !result.exists, exists, isHittable { tap() }
            if result.exists(within: attempt > 0 ? 10 : 3) || !exists { break }
        }
        XCTAssertTrue(result.exists(within: 10), "\(self) didn't open \(result)", file: file, line: line)
    }
}

@MainActor
extension XCUIElementQuery {
    /// `XCUIElement.matches(_:within:)` for a query (`count == 3`).
    func matches(_ predicate: NSPredicate, within timeout: TimeInterval) -> Bool {
        predicate.evaluate(with: self) || poll(timeout, until: { predicate.evaluate(with: self) })
    }
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
