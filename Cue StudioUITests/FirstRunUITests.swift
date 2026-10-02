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

    // MARK: - Dictation

    /// Speak → see the words → review → send. The simulator can't recognize speech, so a scripted
    /// recognizer "hears" the idea a word at a time (`-uiTestDictation speech`).
    func testDictatingAnIdeaShowsTheWordsAndNeverSendsThemByItself() {
        let app = dictationApp("speech", text: "a video about my morning coffee routine")
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let send = app.buttons["empty.ideaSubmit"]
        let mic = app.buttons["empty.ideaDictate"]
        XCTAssertEqual(mic.label, "Dictate your idea")
        XCTAssertFalse(send.isEnabled)

        mic.tap()
        // It says it is listening, the microphone is now the way to stop, and nothing can be sent yet.
        let status = element(app, "empty.dictationStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel(status, "Listening…"))
        XCTAssertEqual(mic.label, "Stop dictation")
        XCTAssertFalse(send.isEnabled)
        // The words appear as they are said.
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'coffee'")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(send.isEnabled)

        mic.tap()
        // Stopped: the words stay, in the field, to review and edit. Nothing was sent.
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "a video about my morning coffee routine")
        XCTAssertFalse(status.exists)
        XCTAssertEqual(mic.label, "Dictate your idea")
        XCTAssertTrue(send.isEnabled)
        XCTAssertFalse(app.buttons["editor.doneButton"].exists)

        // Reviewing: typing continues from the words, and only then does the arrow send.
        // A tap at the far right puts the caret after the last word.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        field.typeText(" today")
        XCTAssertEqual(field.value as? String, "a video about my morning coffee routine today")
        send.tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 15))
    }

    /// What was typed first stays, the idea goes after it, and the kind picked with it is kept.
    func testDictationAddsToWhatIsAlreadyTypedAndKeepsTheKind() {
        let app = dictationApp("speech", text: "and the first hour matters")
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        app.buttons["empty.idea.tip"].tap()
        field.typeText("Morning routine tips")

        app.buttons["empty.ideaDictate"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'matters'")).firstMatch.waitForExistence(timeout: 10))
        // Picking another kind while it listens only changes the question.
        app.buttons["empty.idea.story"].tap()
        XCTAssertEqual(element(app, "empty.ideaQuestion").label, "What happened?")
        app.buttons["empty.ideaDictate"].tap()

        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "Morning routine tips and the first hour matters")
        XCTAssertTrue(app.buttons["empty.idea.story"].isSelected)
    }

    /// Two dictations in a row each add after the last, and a stop with nothing said says so.
    func testSeveralDictationsInARowAddUpAndSilenceIsSaid() {
        let app = dictationApp("speech", text: "first idea")
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let mic = app.buttons["empty.ideaDictate"]
        for _ in 0..<2 {
            mic.tap()
            XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'idea'")).firstMatch.waitForExistence(timeout: 10))
            mic.tap()
            XCTAssertTrue(field.waitForExistence(timeout: 10))
        }
        XCTAssertEqual(field.value as? String, "first idea first idea")
        app.terminate()

        let quiet = dictationApp("silence", text: "")
        let quietField = element(quiet, "empty.ideaField")
        XCTAssertTrue(quietField.waitForExistence(timeout: 15))
        quiet.buttons["empty.ideaDictate"].tap()
        XCTAssertTrue(waitForLabel(element(quiet, "empty.dictationStatus"), "Listening…"))
        quiet.buttons["empty.ideaDictate"].tap()
        XCTAssertTrue(element(quiet, "empty.dictationNotice").waitForExistence(timeout: 10))
        XCTAssertTrue(quiet.staticTexts["Didn’t catch anything. Try again, or type your idea."].exists)
        // Typing still works.
        quietField.tap()
        quietField.typeText("Typed instead")
        XCTAssertEqual(quietField.value as? String, "Typed instead")
    }

    /// A microphone turned off, or a language this iPhone can't recognize: a short note, no crash,
    /// and typing works as before.
    func testWhenDictationCantRunTheCreatorIsToldAndCanStillType() {
        let denied = dictationApp("denied", text: "")
        let deniedField = element(denied, "empty.ideaField")
        XCTAssertTrue(deniedField.waitForExistence(timeout: 15))
        deniedField.tap()
        deniedField.typeText("Already typed")
        denied.buttons["empty.ideaDictate"].tap()
        XCTAssertTrue(element(denied, "empty.dictationNotice").waitForExistence(timeout: 5))
        XCTAssertTrue(denied.buttons["Open Settings"].exists)
        // What was typed is untouched, and the field is still there.
        XCTAssertEqual(deniedField.value as? String, "Already typed")
        XCTAssertEqual(denied.buttons["empty.ideaDictate"].label, "Dictate your idea")
        XCTAssertTrue(denied.buttons["empty.ideaSubmit"].isEnabled)
        denied.terminate()

        let unavailable = dictationApp("unavailable", text: "")
        XCTAssertTrue(element(unavailable, "empty.ideaField").waitForExistence(timeout: 15))
        unavailable.buttons["empty.ideaDictate"].tap()
        XCTAssertTrue(element(unavailable, "empty.dictationNotice").waitForExistence(timeout: 5))
        XCTAssertTrue(unavailable.staticTexts.containing(NSPredicate(format: "label CONTAINS 'type your idea'")).firstMatch.exists)
        XCTAssertFalse(unavailable.buttons["Open Settings"].exists)
    }

    /// Leaving the screen lets the microphone go: another tab, and back, finds an ordinary field.
    func testLeavingTheScreenEndsTheDictationAndKeepsTheWords() {
        let app = dictationApp("speech", text: "a very long idea that keeps going")
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        app.buttons["empty.ideaDictate"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'idea'")).firstMatch.waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["empty.ideaDictate"].label, "Dictate your idea")
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

    /// An empty library with dictation scripted (`-uiTestDictation`).
    private func dictationApp(_ scenario: String, text: String) -> XCUIApplication {
        CueApp.launch(seeded: false, extraArguments: ["-uiTestDictation", scenario, "-uiTestDictationText", text])
    }

    /// Waits for `element`'s label to become `label` (the status row changes from "Getting ready" to "Listening…").
    private func waitForLabel(_ element: XCUIElement, _ label: String, timeout: TimeInterval = 10) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if element.exists, element.label == label { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
