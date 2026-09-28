//
//  QuickEditUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Quick edit from a take's review: trim tools, captions, Done.
@MainActor
final class QuickEditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSplittingDeletingAndSavingAnEdit() {
        let app = openQuickEdit()
        let duration = app.staticTexts["edit.durationChange"]
        XCTAssertTrue(duration.waitForExistence(timeout: 5))
        XCTAssertEqual(duration.label, "1:02 → 1:02")

        app.buttons["edit.splitButton"].tap()
        // After a split nothing is selected (as in the prototype): tap the section after the cut.
        app.descendants(matching: .any)["edit.timeline"].coordinate(withNormalizedOffset: CGVector(dx: 0.7, dy: 0.5)).tap()
        app.buttons["edit.deleteButton"].tap()
        XCTAssertTrue(app.staticTexts["Section deleted"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(app.staticTexts["edit.durationChange"].label, "1:02 → 1:02")

        app.buttons["edit.tool.filters"].tap()
        XCTAssertTrue(app.buttons["edit.filter.mono"].waitForExistence(timeout: 5))
        app.buttons["edit.filter.mono"].tap()

        app.buttons["edit.doneButton"].tap()
        XCTAssertTrue(app.staticTexts["EDITED"].waitForExistence(timeout: 5))
    }

    func testCaptionsComeFromTheScript() {
        let app = openQuickEdit()
        app.buttons["edit.tool.captions"].tap()
        let toggle = app.switches["edit.captionsToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        // The switch sits at the trailing edge; the row's center is its label.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let on = NSPredicate(format: "value == '1'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: on, evaluatedWith: toggle)], timeout: 10), .completed)
        app.buttons["edit.cancelButton"].tap()
        XCTAssertTrue(app.buttons["review.editButton"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func openQuickEdit() -> XCUIApplication {
        let app = CueApp.launch(seeded: true)
        let tab = app.tabBars.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        return app
    }
}
