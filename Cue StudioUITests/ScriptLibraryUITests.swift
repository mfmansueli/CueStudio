//
//  ScriptLibraryUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Browsing, filtering, opening and editing scripts.
@MainActor
final class ScriptLibraryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testHeroShowsTheLastEditedScript() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.staticTexts["3 morning habits that changed my life"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["hero.recordButton"].exists)
        XCTAssertTrue(app.buttons["hero.studioButton"].exists)
    }

    func testFilteringByDestination() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.staticTexts["Unboxing the Lumen desk lamp"].waitForExistence(timeout: 15))
        app.buttons["Reels"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Unboxing the Lumen desk lamp"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Oat & Co. — sponsored read"].exists)
    }

    func testSearch() {
        let app = CueApp.launch(seeded: true)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("Q&A")
        XCTAssertTrue(app.staticTexts["Weekly Q&A — episode 12"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Unboxing the Lumen desk lamp"].exists)
    }

    func testOpeningAndCancellingAnEdit() {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()

        let edit = app.buttons["detail.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 5))
        app.buttons["editor.cancelButton"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
    }

    func testDestinationSheetChangesThePreset() {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()

        app.buttons["detail.destinationButton"].firstMatch.tap()
        let youtube = app.buttons.containing(NSPredicate(format: "label CONTAINS 'YouTube · long-form'")).firstMatch
        XCTAssertTrue(youtube.waitForExistence(timeout: 5))
        youtube.tap()
        XCTAssertTrue(app.staticTexts["16:9 · 4K24"].waitForExistence(timeout: 5))
    }

    func testSelectingAndDeleting() {
        let app = CueApp.launch(seeded: true)
        let select = app.buttons["scripts.selectButton"]
        XCTAssertTrue(select.waitForExistence(timeout: 15))
        select.tap()
        app.staticTexts["Unboxing the Lumen desk lamp"].tap()
        app.buttons["scripts.deleteSelectionButton"].tap()
        XCTAssertTrue(app.staticTexts["1 deleted"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Unboxing the Lumen desk lamp"].exists)
    }
}
