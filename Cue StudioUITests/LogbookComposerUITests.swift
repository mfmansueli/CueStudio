//
//  LogbookComposerUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Logbook's field and its button, made solid (owner, 05/11/2026): the button stays in the middle of the field's end as the field
/// grows, a capture that stops on its own keeps what was heard and lets the button rest, the words left in the field wait for the next
/// visit, a tap opens a long idea whole, and where the microphone is off the line says so with the way to Settings. With
/// `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>` each test saves a picture.
@MainActor
final class LogbookComposerUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { return }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: folder.appending(path: "logbook-\(name).png"))
    }

    private func openLogbook(_ app: XCUIApplication) -> XCUIElement {
        let button = app.buttons["scripts.logbookButton"]
        XCTAssertTrue(button.exists(within: 15))
        button.tap()
        let field = element(app, "logbook.field")
        XCTAssertTrue(field.exists(within: 5), "The Logbook did not open")
        return field
    }

    func testTheButtonStaysInTheMiddleOfTheFieldAsItGrows() {
        let app = CueApp.launch(seeded: true)
        let field = openLogbook(app)
        let microphone = element(app, "logbook.captureButton")
        XCTAssertTrue(microphone.exists(within: 5))
        XCTAssertEqual(microphone.frame.midY, field.frame.midY, accuracy: 1.5, "The microphone is not in the middle of the empty field")
        shot(app, "1-empty")
        field.tap()
        field.typeText("A video about the three small habits that made my slow mornings work, and the one I dropped after a week")
        let save = app.buttons["logbook.save"]
        XCTAssertTrue(save.exists(within: 5))
        XCTAssertGreaterThan(field.frame.height, 60, "The field did not grow with the idea")
        XCTAssertEqual(save.frame.midY, field.frame.midY, accuracy: 1.5, "The arrow is not in the middle of the grown field")
        shot(app, "2-grown")
    }

    /// The recognizer stops on its own after a tap started it (a call, the microphone gone): what was heard is saved, the line says it
    /// stopped, and the button is a button again, not one still pretending to listen.
    func testACaptureThatStopsOnItsOwnKeepsWhatWasHeard() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDictation", "interrupted", "-uiTestDictationText", "a video about slow mornings"])
        _ = openLogbook(app)
        let microphone = element(app, "logbook.captureButton")
        XCTAssertTrue(microphone.exists(within: 5))
        microphone.tap()
        XCTAssertTrue(element(app, "logbook.tapToFinish").exists(within: 5), "The tap did not start listening")
        XCTAssertTrue(element(app, "logbook.entry").exists(within: 10), "What was heard before it stopped was lost")
        XCTAssertTrue(element(app, "logbook.tapToFinish").isGone(within: 3), "It still says to tap again after it stopped")
        let line = element(app, "logbook.status")
        XCTAssertTrue(line.exists(within: 3), "Nothing says it stopped")
        XCTAssertTrue(line.label.contains("Dictation stopped"), "The line says \(line.label)")
        shot(app, "3-stopped")
        // The next tap starts listening again, it doesn't end a capture already over.
        microphone.tap()
        XCTAssertTrue(element(app, "logbook.tapToFinish").exists(within: 5), "The button did not come back to rest")
    }

    func testTheWordsLeftInTheFieldWaitForTheNextVisit() {
        let app = CueApp.launch(seeded: true)
        let field = openLogbook(app)
        field.tap()
        field.typeText("Half an idea about desk lamps")
        app.navigationBars.buttons["logbook.doneButton"].tap()
        XCTAssertTrue(field.isGone(within: 5))
        let again = openLogbook(app)
        XCTAssertEqual(again.value as? String, "Half an idea about desk lamps", "The unsent words were lost")
        XCTAssertTrue(app.buttons["logbook.save"].exists, "The words came back but the arrow didn't")
    }

    func testATapOpensALongIdeaWhole() {
        let app = CueApp.launch(seeded: true)
        let field = openLogbook(app)
        field.tap()
        let long = "Start with the mug, the steam and the window, then the alarm I stopped snoozing, the walk before the phone, the "
            + "notebook with three lines, the breakfast that takes four minutes, and end on why none of it is about waking up earlier"
        field.typeText(long + "\n")
        let entry = element(app, "logbook.entry")
        XCTAssertTrue(entry.exists(within: 5))
        // A tap on the page (its first day's title) puts the keyboard away.
        element(app, "logbook.day").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        entry.waitUntilStill()
        let folded = entry.frame.height
        entry.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).tap()
        entry.waitUntilStill()
        XCTAssertGreaterThan(entry.frame.height, folded + 30, "The tap did not open the whole idea")
        shot(app, "4-open")
        entry.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.5)).tap()
        entry.waitUntilStill()
        XCTAssertEqual(entry.frame.height, folded, accuracy: 2, "Another tap did not fold it")
    }

    func testWhereTheMicrophoneIsOffTheLineShowsTheWayToSettings() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDictation", "denied"])
        _ = openLogbook(app)
        let microphone = element(app, "logbook.captureButton")
        XCTAssertTrue(microphone.exists(within: 5))
        microphone.tap()
        XCTAssertTrue(app.buttons["logbook.openSettings"].exists(within: 5), "No way to turn the microphone on")
        XCTAssertFalse(element(app, "logbook.tapToFinish").exists, "It keeps listening to nothing")
        shot(app, "5-denied")
    }

    /// While it listens the field keeps its one line and the words run through it like captions: the button never moves under the finger.
    /// The idea lands open, whole.
    func testWhileItListensTheFieldKeepsItsLine() {
        let heard = "a video about the three small habits that made my slow mornings work and the one I dropped after a week of trying"
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDictation", "speech", "-uiTestDictationText", heard])
        let field = openLogbook(app)
        let microphone = element(app, "logbook.captureButton")
        XCTAssertTrue(microphone.exists(within: 5))
        let resting = microphone.frame
        let fieldHeight = field.frame.height
        microphone.tap()
        let caption = element(app, "logbook.liveCaption")
        XCTAssertTrue(caption.matches(NSPredicate(format: "label CONTAINS 'after a week'"), within: 15), "Nothing was heard")
        shot(app, "6-caption")
        XCTAssertEqual(field.frame.height, fieldHeight, accuracy: 1, "The field grew while it listened")
        XCTAssertLessThanOrEqual(caption.frame.maxX, microphone.frame.minX, "The words run under the button")
        shot(app, "6-caption")
        XCTAssertEqual(microphone.frame.midY, resting.midY, accuracy: 1, "The button moved while it listened")
        microphone.tap()
        let entry = element(app, "logbook.entry")
        XCTAssertTrue(entry.exists(within: 10))
        entry.waitUntilStill()
        XCTAssertGreaterThan(entry.frame.height, 120, "The spoken idea did not land open")
        shot(app, "7-landed")
    }

    /// Swipe a card, Edit (beside Delete): its words are in the field to correct, Return saves them in place; Cancel leaves it as it was.
    func testAnIdeaIsCorrectedInPlace() {
        let app = CueApp.launch(seeded: true)
        let field = openLogbook(app)
        field.tap()
        field.typeText("Slow mornigns\n")
        let entry = element(app, "logbook.entry")
        XCTAssertTrue(entry.exists(within: 5))
        element(app, "logbook.day").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        entry.waitUntilStill()
        entry.swipeLeft()
        shot(app, "8-menu")
        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.exists(within: 5), "The swipe offers no Edit")
        edit.tap()
        XCTAssertTrue(element(app, "logbook.editing").exists(within: 5))
        XCTAssertEqual(field.value as? String, "Slow mornigns")
        shot(app, "8-editing")
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 3) + "ngs\n")
        XCTAssertTrue(element(app, "logbook.editing").isGone(within: 5))
        XCTAssertTrue(app.staticTexts["Slow mornings"].exists(within: 5), "The idea was not corrected")
        XCTAssertEqual(app.descendants(matching: .any).matching(identifier: "logbook.entry").count, 1, "The edit made a second idea")
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5), "The keyboard stayed after the edit")
        entry.waitUntilStill()
        entry.swipeLeft()
        XCTAssertTrue(app.buttons["Edit"].exists(within: 5))
        app.buttons["Edit"].tap()
        XCTAssertTrue(app.buttons["logbook.cancelEdit"].exists(within: 5))
        field.typeText(" and coffee")
        app.buttons["logbook.cancelEdit"].tap()
        XCTAssertTrue(app.staticTexts["Slow mornings"].exists(within: 5), "Cancel changed the idea")
        XCTAssertNotEqual(field.value as? String, "Slow mornings and coffee", "Cancel left the edit in the field")
    }

    /// The real movement of a card opening and folding, for a screen recording (`xcrun simctl io booted recordVideo`); only with a capture
    /// folder.
    func testTheCardOpensForTheRecording() throws {
        guard ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] != nil else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let app = CueApp.launch(seeded: true, animations: true)
        let field = openLogbook(app)
        field.tap()
        for idea in ["Desk lamps that change the room", "The one habit I kept"] { field.typeText(idea + "\n") }
        field.typeText("Start with the mug, the steam and the window, then the alarm I stopped snoozing, the walk before the phone, and end on why "
            + "none of it is about waking up earlier\n")
        element(app, "logbook.day").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForNonExistence(timeout: 5))
        sleep(2)
        let entry = element(app, "logbook.entry")
        print("CUE-MARK open")
        for _ in 0..<3 {
            entry.coordinate(withNormalizedOffset: CGVector(dx: 0.35, dy: 0.3)).tap()
            sleep(2)
        }
    }
}
