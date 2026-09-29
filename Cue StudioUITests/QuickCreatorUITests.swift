//
//  QuickCreatorUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Quick Creator tools in Quick edit, on a small real (silent) video: the categories, a text
/// added and undone, speed, Remove Pauses, transitions without cuts, a project style and a cover.
@MainActor
final class QuickCreatorUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testCategoriesShowTheirTools() {
        let app = openQuickEdit()
        XCTAssertTrue(app.buttons["edit.tool.trim"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit.tool.removePauses"].exists)
        XCTAssertTrue(app.buttons["edit.tool.speed"].exists)
        app.buttons["edit.category.add"].tap()
        XCTAssertTrue(app.buttons["edit.tool.text"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit.tool.media"].exists)
        XCTAssertTrue(app.buttons["edit.tool.voiceOver"].exists)
        app.buttons["edit.category.polish"].tap()
        XCTAssertTrue(app.buttons["edit.tool.transitions"].waitForExistence(timeout: 5))
        // Back to Edit: it opens on the tool used last there.
        app.buttons["edit.category.edit"].tap()
        XCTAssertTrue(app.buttons["edit.cutButton"].waitForExistence(timeout: 5))
    }

    func testATextIsAddedWrittenAndUndone() {
        let app = openQuickEdit()
        app.buttons["edit.category.add"].tap()
        let title = app.buttons["edit.addText.title"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        // A multi-line field: found by its identifier whatever element type it reports.
        let field = element(app, "textSheet.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(" now")
        app.buttons["textSheet.done"].tap()
        XCTAssertTrue(element(app, "edit.layer.text").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit.editTextButton"].exists)

        app.buttons["edit.undoButton"].tap()
        app.buttons["edit.undoButton"].tap()
        XCTAssertFalse(element(app, "edit.layer.text").waitForExistence(timeout: 2))
        XCTAssertEqual(app.staticTexts["edit.durationChange"].label, "Original · 1:02")
    }

    func testDoubleSpeedHalvesTheVideo() {
        let app = openQuickEdit()
        let speed = app.buttons["edit.tool.speed"]
        XCTAssertTrue(speed.waitForExistence(timeout: 5))
        speed.tap()
        app.buttons["edit.speed.2.0"].tap()
        XCTAssertTrue(app.staticTexts["Video at 2×"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["edit.durationChange"].label, "1:02 → 0:31")
        app.buttons["edit.undoButton"].tap()
        XCTAssertEqual(app.staticTexts["edit.durationChange"].label, "Original · 1:02")
    }

    func testRemovePausesListensFirst() {
        let app = openQuickEdit()
        let tool = app.buttons["edit.tool.removePauses"]
        XCTAssertTrue(tool.waitForExistence(timeout: 5))
        tool.tap()
        // The sample video is silent and has no voice: nothing to take out, nothing is cut.
        let title = app.staticTexts["edit.pausesTitle"]
        XCTAssertTrue(title.waitForExistence(timeout: 15))
        XCTAssertFalse(app.buttons["edit.pausesApplyButton"].isEnabled)
        XCTAssertEqual(app.staticTexts["edit.durationChange"].label, "Original · 1:02")
    }

    func testTransitionsWithoutCutsPointToTrim() {
        let app = openQuickEdit()
        app.buttons["edit.category.polish"].tap()
        app.buttons["edit.tool.transitions"].tap()
        let goToTrim = app.buttons["edit.transitions.goToTrim"]
        XCTAssertTrue(goToTrim.waitForExistence(timeout: 5))
        goToTrim.tap()
        XCTAssertTrue(app.buttons["edit.cutButton"].waitForExistence(timeout: 5))
    }

    func testAStyleSetsTheWholeVideo() {
        let app = openQuickEdit()
        app.buttons["edit.category.polish"].tap()
        let style = app.buttons["edit.tool.style"]
        XCTAssertTrue(style.waitForExistence(timeout: 5))
        style.tap()
        app.buttons["edit.style.bold"].tap()
        XCTAssertTrue(app.staticTexts["Bold style applied"].waitForExistence(timeout: 5))
        app.buttons["edit.doneButton"].tap()
        XCTAssertTrue(app.staticTexts["EDITED"].waitForExistence(timeout: 5))
    }

    func testAFrameBecomesTheCover() {
        let app = openQuickEdit()
        app.buttons["edit.category.cover"].tap()
        let useFrame = app.buttons["edit.coverFrameButton"]
        XCTAssertTrue(useFrame.waitForExistence(timeout: 5))
        useFrame.tap()
        XCTAssertTrue(app.staticTexts["Cover set to this frame"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.textFields["edit.coverTitleField"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "edit.coverPreview").waitForExistence(timeout: 10))
    }

    // MARK: - Helpers

    private func openQuickEdit() -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: true)
        let tab = app.tabBars.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let time = app.staticTexts["edit.timeLabel"]
        let ready = NSPredicate(format: "value == %@", "00:00.00 / 01:02.00")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: ready, evaluatedWith: time)], timeout: 10), .completed)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
