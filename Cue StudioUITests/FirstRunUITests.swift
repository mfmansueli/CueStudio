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

    /// "What's the idea?" is answered in the card: a compact field that opens the composer, no chips,
    /// and a card that keeps its size however long the idea gets.
    func testTheIdeaCardIsACompactFieldThatOpensTheComposerAndKeepsTheDraft() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        // The "+" stays at the top right, the rows below the card are the quiet ones, the chips are gone.
        XCTAssertTrue(app.buttons["scripts.newButton"].exists)
        XCTAssertTrue(app.buttons["empty.writeButton"].exists && app.buttons["empty.importButton"].exists)
        XCTAssertFalse(app.buttons["empty.idea.tip"].exists || app.buttons["empty.idea.product"].exists || app.buttons["empty.idea.story"].exists)
        XCTAssertFalse(element(app, "empty.ideaQuestion").exists)
        XCTAssertFalse(app.buttons["empty.ideaSubmit"].isEnabled)
        let card = element(app, "empty.promptCard")
        let emptyHeight = card.frame.height

        field.tap()
        let text = element(app, "ideaComposer.textField")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "ideaComposer.sheet").exists)
        let create = app.buttons["ideaComposer.createButton"]
        XCTAssertFalse(create.isEnabled)
        text.typeText("Three ways to focus")
        // The arrow of the card is on when something can write the script; without Apple Intelligence it says why.
        let unavailable = element(app, "generate.unavailableNote").exists
        XCTAssertEqual(create.isEnabled, !unavailable)
        app.buttons["sheet.closeButton"].tap()

        // Closing keeps the draft in the card, and the card did not grow.
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "Three ways to focus")
        XCTAssertEqual(app.buttons["empty.ideaSubmit"].isEnabled, !unavailable)
        XCTAssertEqual(card.frame.height, emptyHeight, accuracy: 1)

        // A long idea scrolls inside the field instead of growing the card; reopening shows exactly it.
        field.tap()
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertEqual(text.value as? String, "Three ways to focus")
        let long = Array(repeating: "and another thing about the idea", count: 8).joined(separator: " ")
        text.typeText(" " + long)
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(card.frame.height, emptyHeight, accuracy: 1)
        field.tap()
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        XCTAssertEqual(text.value as? String, "Three ways to focus " + long)
    }

    /// "Create script" and the card's arrow open Generate with AI with the idea filled in; nothing is
    /// written until its own "Generate script" is tapped.
    func testCreateScriptOpensGenerateWithAIAndWritesOnlyAfterItsButton() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        let text = element(app, "ideaComposer.textField")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.typeText("Carnival in Salvador")
        app.buttons["ideaComposer.createButton"].tap()
        // Generate with AI shows the request, the options and the final button, and has not started.
        let prompt = element(app, "generate.promptField")
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(prompt.value as? String, "Carnival in Salvador")
        XCTAssertFalse(app.buttons["2 minutes on how the electric shower was invented in Brazil"].exists)
        let generate = app.buttons["generate.generateButton"]
        XCTAssertTrue(generate.exists)
        XCTAssertFalse(app.buttons["editor.doneButton"].waitForExistence(timeout: 2))
        // The voice is off for a profile that was never set up, and writing works without it.
        XCTAssertEqual(app.switches["generate.voiceToggle"].value as? String, "0")
        generate.tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 15))
        app.buttons["editor.doneButton"].tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 5))
    }

    func testTheCardsArrowSendsTheDraftToTheSameFlow() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        let text = element(app, "ideaComposer.textField")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.typeText("Why I quit coffee")
        app.buttons["sheet.closeButton"].tap()
        let send = app.buttons["empty.ideaSubmit"]
        XCTAssertTrue(send.waitForExistence(timeout: 5))
        send.tap()
        let prompt = element(app, "generate.promptField")
        XCTAssertTrue(prompt.waitForExistence(timeout: 5))
        XCTAssertEqual(prompt.value as? String, "Why I quit coffee")
        XCTAssertFalse(app.buttons["editor.doneButton"].waitForExistence(timeout: 2))
        // Closing without generating keeps the draft in the card.
        app.buttons["Close"].firstMatch.tap()
        XCTAssertEqual(field.value as? String, "Why I quit coffee")
        send.tap()
        XCTAssertTrue(app.buttons["generate.generateButton"].waitForExistence(timeout: 5))
        app.buttons["generate.generateButton"].tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 15))
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
    /// questions, saves them in Profile, and cancelling changes nothing.
    func testWriteInMyVoiceAsksForTheMissingProfileThenSharesItsStateWithGenerate() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        let text = element(app, "ideaComposer.textField")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.typeText("Carnival in Salvador")
        app.buttons["sheet.closeButton"].tap()

        let toggle = app.switches["empty.voiceToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertFalse(app.buttons["empty.editStyleButton"].exists)

        // Cancel: the switch stays off and the text is kept.
        toggle.tap()
        let save = app.buttons["voiceSetup.saveButton"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        XCTAssertFalse(save.isEnabled)
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        XCTAssertEqual(field.value as? String, "Carnival in Salvador")

        // Answer the three questions: the switch turns on and the style can be edited.
        toggle.tap()
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        app.buttons["voiceSetup.niche.lifestyle"].tap()
        XCTAssertFalse(save.isEnabled)
        app.buttons["voiceSetup.audience.genZ"].tap()
        app.buttons["voiceSetup.tone.funny"].tap()
        XCTAssertTrue(save.isEnabled)
        save.tap()
        XCTAssertTrue(app.buttons["empty.editStyleButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertEqual(field.value as? String, "Carnival in Salvador")

        // Generate shows the same switch, on; turning it off there turns it off on the card too.
        app.buttons["scripts.newButton"].tap()
        app.buttons["newScript.prompt"].tap()
        let generateToggle = app.switches["generate.voiceToggle"]
        XCTAssertTrue(generateToggle.waitForExistence(timeout: 5))
        XCTAssertEqual(generateToggle.value as? String, "1")
        generateToggle.tap()
        XCTAssertEqual(generateToggle.value as? String, "0")
        app.buttons["Close"].firstMatch.tap()
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        XCTAssertEqual(toggle.value as? String, "0")
        // With the profile complete it turns on directly, with no questions.
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "1")
        XCTAssertFalse(app.buttons["voiceSetup.saveButton"].exists)
    }

    // MARK: - Dictation

    /// Speak → see the words in the composer → review → create. The simulator can't recognize
    /// speech, so a scripted recognizer "hears" the idea a word at a time (`-uiTestDictation speech`).
    func testDictatingAnIdeaInTheComposerShowsTheWordsAndNeverSendsThemByItself() {
        let app = dictationApp("speech", text: "a video about my morning coffee routine")
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertEqual(app.buttons["empty.ideaDictate"].label, "Dictate your idea")
        XCTAssertFalse(app.buttons["empty.ideaSubmit"].isEnabled)

        // The card's microphone opens the composer and starts listening once it is shown.
        app.buttons["empty.ideaDictate"].tap()
        let mic = app.buttons["ideaComposer.dictate"]
        let create = app.buttons["ideaComposer.createButton"]
        XCTAssertTrue(mic.waitForExistence(timeout: 5))
        let status = element(app, "empty.dictationStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(waitForLabel(status, "Listening…"))
        // The microphone is now the way to stop, and nothing can be created yet.
        XCTAssertEqual(mic.label, "Stop dictation")
        XCTAssertFalse(create.isEnabled)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'coffee'")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(create.isEnabled)

        mic.tap()
        // Stopped: the words stay, in the editor, to review. Nothing was sent.
        let text = element(app, "ideaComposer.textField")
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        XCTAssertEqual(text.value as? String, "a video about my morning coffee routine")
        XCTAssertFalse(status.exists)
        XCTAssertEqual(mic.label, "Dictate your idea")
        XCTAssertFalse(app.buttons["editor.doneButton"].exists)
        let unavailable = element(app, "generate.unavailableNote").exists
        XCTAssertEqual(create.isEnabled, !unavailable)

        // Dictating on adds after the words; closing keeps all of it in the card.
        mic.tap()
        XCTAssertTrue(waitForLabel(status, "Listening…"))
        mic.tap()
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        XCTAssertEqual(text.value as? String, "a video about my morning coffee routine a video about my morning coffee routine")
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "a video about my morning coffee routine a video about my morning coffee routine")
    }

    /// Closing the sheet while listening stops the microphone and keeps what was heard.
    func testClosingTheComposerWhileListeningKeepsTheWordsAndReleasesTheMicrophone() {
        let app = dictationApp("speech", text: "a very long idea that keeps going")
        let field = element(app, "empty.ideaField")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        app.buttons["empty.ideaDictate"].tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'idea'")).firstMatch.waitForExistence(timeout: 10))
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["empty.ideaDictate"].label, "Dictate your idea")
        let value = field.value as? String ?? ""
        XCTAssertTrue(value.hasPrefix("a very long idea"))
        // The words are still there on reopening, and nothing keeps listening.
        field.tap()
        let text = element(app, "ideaComposer.textField")
        XCTAssertTrue(text.waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "empty.dictationStatus").exists)
    }

    /// A silent dictation says so; typing still works.
    func testSilenceIsSaidAndTypingStillWorks() {
        let quiet = dictationApp("silence", text: "")
        XCTAssertTrue(element(quiet, "empty.ideaField").waitForExistence(timeout: 15))
        quiet.buttons["empty.ideaDictate"].tap()
        XCTAssertTrue(waitForLabel(element(quiet, "empty.dictationStatus"), "Listening…"))
        quiet.buttons["ideaComposer.dictate"].tap()
        XCTAssertTrue(element(quiet, "empty.dictationNotice").waitForExistence(timeout: 10))
        XCTAssertTrue(quiet.staticTexts["Didn’t catch anything. Try again, or type your idea."].exists)
        let text = element(quiet, "ideaComposer.textField")
        text.tap()
        text.typeText("Typed instead")
        XCTAssertEqual(text.value as? String, "Typed instead")
    }

    /// A microphone turned off, or a language this iPhone can't recognize: a short note, no crash,
    /// and typing works as before.
    func testWhenDictationCantRunTheCreatorIsToldAndCanStillType() {
        let denied = dictationApp("denied", text: "")
        let deniedField = element(denied, "empty.ideaField")
        XCTAssertTrue(deniedField.waitForExistence(timeout: 15))
        deniedField.tap()
        let deniedText = element(denied, "ideaComposer.textField")
        XCTAssertTrue(deniedText.waitForExistence(timeout: 5))
        deniedText.typeText("Already typed")
        denied.buttons["ideaComposer.dictate"].tap()
        XCTAssertTrue(element(denied, "empty.dictationNotice").waitForExistence(timeout: 5))
        XCTAssertTrue(denied.buttons["Open Settings"].exists)
        // What was typed is untouched, and the editor is still there.
        XCTAssertEqual(deniedText.value as? String, "Already typed")
        XCTAssertEqual(denied.buttons["ideaComposer.dictate"].label, "Dictate your idea")
        denied.terminate()

        let unavailable = dictationApp("unavailable", text: "")
        XCTAssertTrue(element(unavailable, "empty.ideaField").waitForExistence(timeout: 15))
        unavailable.buttons["empty.ideaDictate"].tap()
        XCTAssertTrue(element(unavailable, "empty.dictationNotice").waitForExistence(timeout: 5))
        XCTAssertTrue(unavailable.staticTexts.containing(NSPredicate(format: "label CONTAINS 'type your idea'")).firstMatch.exists)
        XCTAssertFalse(unavailable.buttons["Open Settings"].exists)
        // Typing is there as before.
        XCTAssertTrue(element(unavailable, "ideaComposer.textField").exists)
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
