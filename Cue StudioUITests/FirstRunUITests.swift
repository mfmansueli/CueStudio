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
        XCTAssertTrue(element(app, "empty.promptCard").exists)
        write.tap()

        let title = element(app, "editor.titleField")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("My first script")

        let text = element(app, "editor.paragraph.0")
        text.tap()
        text.typeText("Hello there. [pause]\nThis is my first script.")

        app.buttons["editor.doneButton"].tap()
        XCTAssertTrue(app.staticTexts["My first script"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["detail.recordButton"].exists)
    }

    /// "What's the idea?" is answered in the card; a chip only picks the question and never touches the text.
    func testTheIdeaCardTakesTheTextAndKeepsItWhenTheKindChanges() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        // The "+" stays at the top right, and the rows below the card are the quiet ones.
        XCTAssertTrue(app.buttons["scripts.newButton"].exists)
        XCTAssertTrue(app.buttons["empty.writeButton"].exists && app.buttons["empty.importButton"].exists)
        XCTAssertFalse(app.buttons["empty.generateButton"].exists)
        // Nothing can be sent from an empty field.
        let send = app.buttons["empty.ideaSubmit"]
        XCTAssertFalse(send.isEnabled)

        let tip = app.buttons["empty.idea.tip"]
        let story = app.buttons["empty.idea.story"]
        tip.tap()
        XCTAssertTrue(element(app, "empty.ideaQuestion").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "empty.ideaQuestion").label, "What do you want to teach?")
        XCTAssertTrue(tip.isSelected)
        XCTAssertFalse(send.isEnabled)

        field.typeText("Three ways to focus")
        XCTAssertEqual(field.value as? String, "Three ways to focus")
        // Another kind: the question changes, one chip at a time, and the text stays.
        story.tap()
        XCTAssertEqual(element(app, "empty.ideaQuestion").label, "What happened?")
        XCTAssertTrue(story.isSelected && !tip.isSelected)
        XCTAssertEqual(field.value as? String, "Three ways to focus")
        // The same chip again goes back to a free idea.
        story.tap()
        XCTAssertFalse(element(app, "empty.ideaQuestion").exists)
        XCTAssertEqual(field.value as? String, "Three ways to focus")
        // The arrow is on when something can write the script; without Apple Intelligence it says why instead.
        let unavailable = element(app, "generate.unavailableNote").exists
        XCTAssertEqual(send.isEnabled, !unavailable)
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
