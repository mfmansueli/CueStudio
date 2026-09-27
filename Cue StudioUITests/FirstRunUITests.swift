//
//  FirstRunUITests.swift
//  Cue StudioUITests
//

import XCTest

/// An empty library nudges toward a script, but recording right away works too.
@MainActor
final class FirstRunUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testWritingTheFirstScript() {
        let app = CueApp.launch(seeded: false)
        let write = app.buttons["empty.writeButton"]
        XCTAssertTrue(write.waitForExistence(timeout: 15))
        write.tap()

        let title = element(app, "editor.titleField")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("My first script")

        let text = element(app, "editor.textEditor")
        text.tap()
        text.typeText("Hello there. [pause]\nThis is my first script.")

        app.buttons["editor.doneButton"].tap()
        XCTAssertTrue(app.staticTexts["My first script"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["detail.recordButton"].exists)
    }

    func testRecordingWithoutAScript() {
        let app = CueApp.launch(seeded: false)
        let skip = app.buttons["empty.skipButton"]
        XCTAssertTrue(skip.waitForExistence(timeout: 15))
        skip.tap()

        XCTAssertTrue(app.buttons["prompter.addScriptButton"].waitForExistence(timeout: 5))
        app.buttons["prompter.closeButton"].tap()
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
