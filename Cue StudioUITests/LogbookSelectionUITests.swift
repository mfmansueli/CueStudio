//
//  LogbookSelectionUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Logbook's ideas are picked and deleted as scripts are: with Select beside the first day in the Logbook, and with the scripts on
/// Scripts, where the ideas at the end of the list stay while it selects. A deletion has Undo.
@MainActor
final class LogbookSelectionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func wait(for count: Int, of query: XCUIElementQuery, _ message: String) {
        XCTAssertTrue(query.matches(NSPredicate(format: "count == %d", count), within: 5), message)
    }

    /// Opens the Logbook and saves `ideas` by typing them (Return saves each; the keyboard stays for the next).
    private func openLogbook(adding ideas: [String], in app: XCUIApplication) {
        app.buttons["scripts.logbookButton"].tap()
        let field = element(app, "logbook.field")
        XCTAssertTrue(field.exists(within: 5))
        field.tap()
        for idea in ideas { field.typeText(idea + "\n") }
        wait(for: ideas.count, of: app.descendants(matching: .any).matching(identifier: "logbook.entry"), "Not every idea was saved")
    }

    func testSeveralIdeasArePickedAndDeletedTogetherAndUndoBringsThemBack() {
        let app = CueApp.launch(seeded: true)
        openLogbook(adding: ["Slow mornings", "Tiny desk setups", "Packing hacks"], in: app)
        let entries = app.descendants(matching: .any).matching(identifier: "logbook.entry")
        let select = app.buttons["logbook.selectButton"]
        XCTAssertTrue(select.exists(within: 5), "No Select beside the first day")
        select.tap()
        // The capture steps aside for the bar, and the sheet's Done leaves room for the one that ends the selection.
        XCTAssertTrue(element(app, "logbook.field").matches(NSPredicate(format: "exists == false"), within: 3), "The field stayed while selecting")
        XCTAssertFalse(app.navigationBars.buttons["logbook.doneButton"].exists)
        XCTAssertTrue(app.staticTexts["Select ideas"].exists(within: 5))
        entries.element(boundBy: 0).tap()
        entries.element(boundBy: 1).tap()
        XCTAssertTrue(app.staticTexts["2 selected"].exists(within: 3))
        app.buttons["logbook.deleteSelectionButton"].tap()
        wait(for: 1, of: entries, "The two picked ideas weren't deleted")
        XCTAssertTrue(element(app, "logbook.field").exists(within: 5), "Deleting didn't end the selection")
        let undo = app.buttons["Undo"]
        XCTAssertTrue(undo.exists(within: 3), "No Undo in front of the Logbook")
        undo.tap()
        wait(for: 3, of: entries, "Undo didn't bring the ideas back")
    }

    func testTheLogbooksIdeasArePickedWithTheScriptsAndDeletedWithThem() {
        let app = CueApp.launch(seeded: true)
        openLogbook(adding: ["Slow mornings", "Tiny desk setups"], in: app)
        app.navigationBars.buttons["logbook.doneButton"].tap()
        app.buttons["scripts.selectButton"].tap()
        let ideas = app.descendants(matching: .any).matching(identifier: "scripts.logbook.idea")
        let first = ideas.firstMatch
        app.scrollAboveTabBar(to: first)
        XCTAssertEqual(ideas.count, 2, "The Logbook's ideas left the list while it selects")
        first.tap()
        XCTAssertTrue(app.staticTexts["1 selected"].exists(within: 3))
        app.buttons["scripts.deleteSelectionButton"].tap()
        wait(for: 1, of: ideas, "The picked idea wasn't deleted with the selection")
        XCTAssertTrue(app.buttons["Undo"].exists(within: 3))
    }
}
