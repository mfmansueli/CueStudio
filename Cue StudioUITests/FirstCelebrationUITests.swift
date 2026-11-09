//
//  FirstCelebrationUITests.swift
//  Cue StudioUITests
//

import XCTest

/// D4 · the first celebration (owner, 09/11/2026): the first journey has at most one full screen. The creator's first recording (a freestyle take with
/// the stand-in camera) opens its review with no story over it; posting it right away makes the send-off the celebration, with the first star and
/// the Aurora icon in it and nothing after it; leaving without a post lights the first star on the video's card in Takes, with no screen at all.
@MainActor
final class FirstCelebrationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testPostingRightAwayIsOneSendOffWithTheFirstStarAndAuroraInIt() {
        let app = recordFirstTake(animations: true)
        XCTAssertFalse(element(app, "firstStar.sheet").exists, "no story over the review")
        postRightAway(app)

        XCTAssertEqual(element(app, "sendoff.headline").label, "FIRST VIDEO · FIRST STAR", "the send-off tells the first star")
        let use = app.buttons["sendoff.icon.use"]
        XCTAssertTrue(use.exists(within: 10), "Aurora is offered in the send-off, once the stars land")
        XCTAssertTrue(element(app, "sendoff.icon.title").label.contains("Aurora icon unlocked"), element(app, "sendoff.icon.title").label)
        use.tap()
        XCTAssertTrue(element(app, "sendoff.icon.inUse").exists(within: 5), "the row says it is in use, and the send-off stays")
        XCTAssertTrue(element(app, "sendoff.sheet").exists)

        // "See your universe" ends it the way Done does: no screen after it.
        element(app, "sendoff.universeLink").tap()
        XCTAssertTrue(element(app, "sendoff.sheet").waitForNonExistence(timeout: 10))
        sleep(1)
        XCTAssertFalse(element(app, "milestone.sheet").exists, "no milestone screen after the send-off")
        XCTAssertFalse(element(app, "firstStar.sheet").exists, "no first-star screen")
        // The review goes back to the camera it came from; Profile is the tab under it.
        let close = app.buttons["prompter.closeButton"]
        if close.exists(within: 5) { close.tap() }
        XCTAssertTrue(app.cueTabBar.buttons["Profile"].isSelected, "See your universe goes to Profile")
        // The send-off told the star: Takes doesn't light it again.
        app.cueTabBar.buttons["Takes"].tap()
        let card = firstVideoCard(app)
        XCTAssertTrue(card.exists(within: 10))
        XCTAssertFalse(card.label.contains("First star"), card.label)
    }

    func testLeavingWithoutPostingShowsNoScreenAndLightsTheStarInTakes() {
        let app = recordFirstTake()
        // The review stays the review: no story covers it, now or a moment later.
        sleep(2)
        XCTAssertFalse(element(app, "firstStar.sheet").exists)
        XCTAssertTrue(app.buttons["review.shareButton"].isHittable)

        app.buttons["review.backButton"].tap()
        let close = app.buttons["prompter.closeButton"]
        XCTAssertTrue(close.exists(within: 10), "back to the camera")
        close.tap()
        XCTAssertFalse(element(app, "firstStar.sheet").exists)
        app.cueTabBar.buttons["Takes"].tap()
        let card = firstVideoCard(app)
        XCTAssertTrue(card.exists(within: 10))
        XCTAssertTrue(card.matches(NSPredicate(format: "label CONTAINS 'First star'"), within: 5), "lit on the video's card: \(card.label)")

        // Another tab and back: the star stays on its card (told once; `TakesFirstStarTests` covers that it never lights again).
        app.cueTabBar.buttons["Scripts"].tap()
        app.cueTabBar.buttons["Takes"].tap()
        XCTAssertTrue(firstVideoCard(app).label.contains("First star"))
    }

    // MARK: - Helpers

    private func firstVideoCard(_ app: XCUIApplication) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.'")).firstMatch
    }
}
