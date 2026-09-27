//
//  TakesUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Takes library (one row per video, filters, day sections) and the take review.
@MainActor
final class TakesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLibraryShowsVideosByDayAndFilters() {
        let app = openTakes()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Yesterday"].exists)
        XCTAssertTrue(videoRow(app, containing: "3 morning habits").exists)
        XCTAssertTrue(videoRow(app, containing: "3 takes · Best: Take 3").exists)

        app.buttons["takes.platform.youtube"].tap()
        XCTAssertTrue(videoRow(app, containing: "Weekly Q&A").waitForExistence(timeout: 5))
        XCTAssertFalse(videoRow(app, containing: "3 morning habits").exists)

        app.buttons["takes.platform.all"].tap()
        app.buttons["takes.view.notShared"].tap()
        XCTAssertTrue(videoRow(app, containing: "3 morning habits").waitForExistence(timeout: 5))
        XCTAssertFalse(videoRow(app, containing: "Unboxing the Lumen").exists)
    }

    func testReviewSwitchesBetweenTakesAndPicksTheBest() {
        let app = openTakes()
        let row = videoRow(app, containing: "3 morning habits")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let label = app.descendants(matching: .any)["review.takeLabel"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertTrue(label.label.contains("Take 3"))
        let takeOne = app.buttons["review.strip.1"]
        XCTAssertTrue(takeOne.exists)
        takeOne.tap()
        XCTAssertTrue(app.descendants(matching: .any)["review.takeLabel"].label.contains("Take 1"))

        app.buttons["review.bestButton"].tap()
        XCTAssertTrue(app.staticTexts["Take 1 marked as best"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["review.bestButton"].value as? String, "On")
    }

    func testDeletingATakeMovesToAnother() {
        let app = openTakes()
        let row = videoRow(app, containing: "3 morning habits")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let delete = app.buttons["review.deleteButton"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        app.buttons["Delete take"].tap()
        XCTAssertTrue(app.staticTexts["Take 3 deleted"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["review.takeLabel"].label.contains("Take 2"))
    }

    // MARK: - Helpers

    private func openTakes() -> XCUIApplication {
        let app = CueApp.launch(seeded: true)
        let tab = app.tabBars.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        return app
    }

    private func videoRow(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS %@", text)).firstMatch
    }
}
