//
//  ShareReturnUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Coming back from the real system share sheet (no stand-in): the networks' sheet closes, the system sheet goes up, and when it ends "Posted on
/// TikTok?" comes up without the review behind it being left zoomed or the app stopping. The sheet is the system's: "Copy" ends it as a finished activity.
@MainActor
final class ShareReturnUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testTheSystemShareSheetEndsAndPostedAsksWithoutFreezingTheApp() {
        // The networks' sheet comes back once the share sheet has animated away: without animations SwiftUI never presents it again.
        let app = CueApp.launch(seeded: true, sampleVideo: true, animations: true)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let share = app.buttons["review.shareButton"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        XCTAssertTrue(element(app, "shareFlow.start").waitForExistence(timeout: 120))
        let ready = element(app, "ready.sheet")
        let before = ready.frame
        app.buttons["shareFlow.start"].tap()
        XCTAssertTrue(waitAllowingPhotos(for: app.buttons["shareFlow.send"]))
        app.buttons["shareFlow.send"].tap()

        // The system share sheet: end it with a finished activity.
        let copy = app.cells["Copy"].firstMatch
        XCTAssertTrue(copy.waitForExistence(timeout: 30), "the system share sheet has Copy")
        copy.tap()

        XCTAssertTrue(element(app, "shareFlow.confirm").waitForExistence(timeout: 15), "Posted on TikTok? comes up")
        // The screen behind is the same size it was, and the app answers.
        XCTAssertEqual(ready.frame.width, before.width, accuracy: 1)
        let notYet = app.buttons["shareFlow.notYet"]
        XCTAssertTrue(notYet.waitForHittable(timeout: 10))
        notYet.tap()
        XCTAssertTrue(element(app, "shareFlow.step").waitForExistence(timeout: 10))
    }
}

private extension XCUIElement {
    /// Waits for the element to exist and be hittable (so a frozen app fails here instead of passing).
    func waitForHittable(timeout: TimeInterval) -> Bool {
        let hittable = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: self)
        return XCTWaiter.wait(for: [hittable], timeout: timeout) == .completed
    }
}
