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

    /// The idea is answered in the card itself: tapping the field takes the keyboard, no
    /// sheet opens, the field keeps its three lines however long the idea gets, and the draft stays.
    func testTheIdeaIsTypedInTheCardWithoutASheetAndTheCardNeverGrows() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        // The "+" stays at the top right, the rows below the card are the quiet ones, the chips are gone.
        XCTAssertTrue(app.buttons["scripts.newButton"].exists)
        XCTAssertTrue(app.buttons["empty.writeButton"].exists && app.buttons["empty.importButton"].exists)
        XCTAssertFalse(app.buttons["empty.idea.tip"].exists || app.buttons["empty.idea.story"].exists)
        XCTAssertFalse(app.buttons["ideaCard.submit"].isEnabled)
        let card = element(app, "empty.promptCard")
        let emptyHeight = card.frame.height

        field.tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        field.typeText("Three ways to focus")
        XCTAssertEqual(field.value as? String, "Three ways to focus")
        let unavailable = element(app, "generate.unavailableNote").exists
        XCTAssertEqual(app.buttons["ideaCard.submit"].isEnabled, !unavailable)

        // A long idea scrolls inside the field instead of growing the card.
        let long = Array(repeating: "and another thing about the idea", count: 8).joined(separator: " ")
        field.typeText(" " + long)
        XCTAssertEqual(card.frame.height, emptyHeight, accuracy: 1)
        XCTAssertEqual(field.value as? String, "Three ways to focus " + long)
    }

    /// The arrow ends the editing and opens Generate with AI with the idea filled in; nothing is
    /// written until its own button, and closing it keeps the draft and the choices made there.
    func testTheArrowOpensGenerateWithAIFilledInAndOnlyItsButtonWrites() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Carnival in Salvador")
        let send = app.buttons["ideaCard.submit"]
        XCTAssertTrue(send.isEnabled)
        send.tap()

        let prompt = element(app, "generate.promptField")
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(prompt.value as? String, "Carnival in Salvador")
        XCTAssertFalse(app.buttons["2 minutes on how the electric shower was invented in Brazil"].exists)
        let generate = app.buttons["generate.generateButton"]
        XCTAssertTrue(generate.exists)
        // Nothing started by itself.
        XCTAssertFalse(app.buttons["editor.doneButton"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["generate.cancelButton"].exists)
        // The voice is off for a profile that was never set up, and writing works without it.
        XCTAssertEqual(app.switches["generate.voiceToggle"].value as? String, "0")

        // A choice made here, and closing: the draft and the choice are still there.
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Carnival in Salvador")
        send.tap()
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 15))
        app.buttons["editor.doneButton"].tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 5))
    }

    /// The same card, with the same behavior, when there are scripts: typed in place, arrow to Generate.
    func testTheSameCardWorksOverTheScriptList() {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["scripts.newButton"].exists)
        XCTAssertTrue(element(app, "ideaCard.voiceToggle").exists)
        field.tap()
        field.typeText("A day in my life")
        XCTAssertEqual(field.value as? String, "A day in my life")
        app.buttons["ideaCard.submit"].tap()
        let prompt = element(app, "generate.promptField")
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(prompt.value as? String, "A day in my life")
        XCTAssertTrue(app.buttons["generate.generateButton"].exists)
        XCTAssertFalse(app.buttons["editor.doneButton"].waitForExistence(timeout: 2))
    }

    /// The Generate screen shows examples only while the prompt is empty: never under a real request.
    func testGenerateWithAIShowsNoExampleUnderTheIdeaItIsWriting() {
        let app = CueApp.launch(seeded: true)
        let plus = app.buttons["scripts.newButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()
        app.buttons["newScript.prompt"].tap()
        let field = element(app, "generate.promptField")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let example = app.buttons["2 minutes on how the electric shower was invented in Brazil"]
        XCTAssertTrue(example.exists)
        field.tap()
        field.typeText("Carnival in Salvador")
        XCTAssertFalse(example.exists)
    }

    // MARK: - Write in my voice

    /// The switch shares its state with Generate; turning it on without a profile asks three short
    /// questions, saves them in Profile, and cancelling changes nothing, the draft included.
    func testWriteInMyVoiceAsksForTheMissingProfileThenSharesItsStateWithGenerate() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Carnival in Salvador")

        let toggle = app.switches["ideaCard.voiceToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.buttons["ideaCard.editStyleButton"].exists)

        // Cancel: the switch stays off and the text is kept.
        flip(toggle)
        let save = app.buttons["voiceSetup.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertEqual(field.value as? String, "Carnival in Salvador")

        // Answer the three questions: the switch turns on and the style can be edited.
        flip(toggle)
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        app.buttons["voiceSetup.niche.lifestyle"].tap()
        XCTAssertFalse(save.isEnabled)
        app.buttons["voiceSetup.audience.genZ"].tap()
        app.buttons["voiceSetup.tone.funny"].tap()
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["ideaCard.editStyleButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(field.value as? String, "Carnival in Salvador")

        // Generate shows the same switch, on; turning it off there turns it off on the card too.
        app.buttons["scripts.newButton"].tap()
        app.buttons["newScript.prompt"].tap()
        let generateToggle = app.switches["generate.voiceToggle"]
        XCTAssertTrue(generateToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(generateToggle.value as? String, "1")
        flip(generateToggle)
        XCTAssertEqual(generateToggle.value as? String, "0")
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        // With the profile complete it turns on directly, with no questions.
        flip(toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertFalse(app.buttons["voiceSetup.saveButton"].exists)
        XCTAssertEqual(field.value as? String, "Carnival in Salvador")
    }

    // MARK: - Dictation

    /// Speak → see the words in the card → review → send. The simulator can't recognize speech, so a
    /// scripted recognizer "hears" the idea a word at a time (`-uiTestDictation speech`).
    func testDictatingInTheCardShowsTheWordsAndNeverSendsThemByItself() {
        let app = dictationApp("speech", text: "a video about my morning coffee routine")
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let mic = app.buttons["ideaCard.dictate"]
        let send = app.buttons["ideaCard.submit"]
        XCTAssertEqual(mic.label, "Dictate your idea")
        XCTAssertFalse(send.isEnabled)
        let card = element(app, "empty.promptCard")
        let height = card.frame.height

        mic.tap()
        // No sheet: it listens right there, and the card keeps its height.
        let status = element(app, "ideaCard.dictationStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel(status, "Listening…"))
        XCTAssertEqual(mic.label, "Stop dictation")
        XCTAssertFalse(send.isEnabled)
        XCTAssertTrue(dictatedWords(app, saying: "coffee").waitForExistence(timeout: 10))
        XCTAssertEqual(card.frame.height, height, accuracy: 1)
        XCTAssertFalse(send.isEnabled)

        mic.tap()
        // Stopped: the words stay in the field, editable. Nothing was sent.
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "a video about my morning coffee routine")
        XCTAssertFalse(status.exists)
        XCTAssertEqual(mic.label, "Dictate your idea")
        XCTAssertFalse(app.buttons["generate.generateButton"].exists)
        XCTAssertEqual(card.frame.height, height, accuracy: 1)
        let unavailable = element(app, "generate.unavailableNote").exists
        XCTAssertEqual(send.isEnabled, !unavailable)

        // A second session adds after the words, without repeating them.
        mic.tap()
        XCTAssertTrue(waitForLabel(status, "Listening…"))
        mic.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.value as? String, "a video about my morning coffee routine a video about my morning coffee routine")
    }

    /// Tapping the words while they are dictated stops it and takes the keyboard to edit them.
    func testTappingTheWordsWhileListeningStopsAndEdits() {
        let app = dictationApp("speech", text: "a very long idea that keeps going")
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        app.buttons["ideaCard.dictate"].tap()
        let transcript = element(app, "ideaCard.transcript")
        XCTAssertTrue(transcript.waitForExistence(timeout: 10))
        XCTAssertTrue(dictatedWords(app, saying: "long idea").waitForExistence(timeout: 10))
        transcript.tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["ideaCard.dictate"].label, "Dictate your idea")
        XCTAssertFalse(element(app, "ideaCard.dictationStatus").exists)
    }

    /// Leaving the screen lets the microphone go and keeps the words.
    func testLeavingTheScreenEndsTheDictationAndKeepsTheWords() {
        let app = dictationApp("speech", text: "a very long idea that keeps going")
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        app.buttons["ideaCard.dictate"].tap()
        XCTAssertTrue(dictatedWords(app, saying: "long idea").waitForExistence(timeout: 10))
        app.tabBars.buttons.element(boundBy: 1).tap()
        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["ideaCard.dictate"].label, "Dictate your idea")
        XCTAssertFalse(element(app, "ideaCard.dictationStatus").exists)
        XCTAssertTrue((field.value as? String ?? "").hasPrefix("a very long idea"))
    }

    /// Asking for the voice setup while dictating lets the dictation write its last words first: the
    /// setup opens once the microphone is off, and every word is still in the field after it.
    func testTheVoiceSetupWaitsForTheDictationToWriteItsLastWords() {
        let app = dictationApp("speech", text: "a video about my morning coffee routine")
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        app.buttons["ideaCard.dictate"].tap()
        XCTAssertTrue(waitForLabel(element(app, "ideaCard.dictationStatus"), "Listening…"))
        XCTAssertTrue(dictatedWords(app, saying: "video about").waitForExistence(timeout: 10))

        flip(app.switches["ideaCard.voiceToggle"])
        let save = app.buttons["voiceSetup.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 10))
        app.buttons["sheet.closeButton"].tap()

        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "a video about my morning coffee routine")
        XCTAssertFalse(element(app, "ideaCard.dictationStatus").exists)
        XCTAssertEqual(app.buttons["ideaCard.dictate"].label, "Dictate your idea")
        XCTAssertEqual(app.switches["ideaCard.voiceToggle"].value as? String, "0")
    }

    /// A silent dictation says so; typing still works.
    func testSilenceIsSaidAndTypingStillWorks() {
        let quiet = dictationApp("silence", text: "")
        let field = element(quiet, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        quiet.buttons["ideaCard.dictate"].tap()
        XCTAssertTrue(waitForLabel(element(quiet, "ideaCard.dictationStatus"), "Listening…"))
        quiet.buttons["ideaCard.dictate"].tap()
        XCTAssertTrue(element(quiet, "ideaCard.dictationNotice").waitForExistence(timeout: 10))
        XCTAssertTrue(quiet.staticTexts["Didn’t catch anything. Try again, or type your idea."].exists)
        field.tap()
        field.typeText("Typed instead")
        XCTAssertEqual(field.value as? String, "Typed instead")
    }

    /// A microphone turned off, or a language this iPhone can't recognize: a short note, no crash,
    /// and typing works as before.
    func testWhenDictationCantRunTheCreatorIsToldAndCanStillType() {
        let denied = dictationApp("denied", text: "")
        let deniedField = element(denied, "ideaCard.field")
        XCTAssertTrue(deniedField.waitForExistence(timeout: 15))
        deniedField.tap()
        deniedField.typeText("Already typed")
        denied.buttons["ideaCard.dictate"].tap()
        XCTAssertTrue(element(denied, "ideaCard.dictationNotice").waitForExistence(timeout: 5))
        XCTAssertTrue(denied.buttons["Open Settings"].exists)
        // What was typed is untouched, and the field is still there.
        XCTAssertEqual(deniedField.value as? String, "Already typed")
        XCTAssertEqual(denied.buttons["ideaCard.dictate"].label, "Dictate your idea")
        denied.terminate()

        let unavailable = dictationApp("unavailable", text: "")
        XCTAssertTrue(element(unavailable, "ideaCard.field").waitForExistence(timeout: 15))
        unavailable.buttons["ideaCard.dictate"].tap()
        XCTAssertTrue(element(unavailable, "ideaCard.dictationNotice").waitForExistence(timeout: 5))
        XCTAssertTrue(unavailable.staticTexts.containing(NSPredicate(format: "label CONTAINS 'type your idea'")).firstMatch.exists)
        XCTAssertFalse(unavailable.buttons["Open Settings"].exists)
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

    /// The words being dictated, as the card shows them while it listens (one element, read-only).
    /// Matched there, not anywhere on screen: "idea" and "video" are also in the card's own texts.
    private func dictatedWords(_ app: XCUIApplication, saying words: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: "ideaCard.transcript")
            .matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    /// Flips a switch by its control. The element spans the whole row, and a tap in its middle
    /// lands on the label, which doesn't flip a SwiftUI switch.
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }
}
