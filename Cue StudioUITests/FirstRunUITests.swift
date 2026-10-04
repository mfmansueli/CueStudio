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

        // A new page opens in the Draft with the title ready.
        // The title is a text field that grows.
        let title = app.textFields["page.titleField"]
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        // The title takes the keyboard on its own: wait for it, then write.
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        title.typeText("My first script")

        // Empty, the Draft shows a hint over its text view: the tests type into the text view.
        let text = app.textViews["page.editor"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText("Hello there. [pause]\nThis is my first script.")

        app.buttons["page.backButton"].tap()
        XCTAssertTrue(app.staticTexts["My first script"].waitForExistence(timeout: 5))
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
        // With nothing written the arrow writes the card's suggested idea ("↻ Another idea" brings the next): it is on.
        XCTAssertTrue(app.buttons["ideaCard.submit"].isEnabled)
        XCTAssertTrue(element(app, "ideaCard.anotherIdea").exists)
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

    /// The arrow ends the editing and writes the idea into a new page: the words arrive on it, the
    /// card is empty again, and the page is a script like any other.
    func testTheArrowWritesTheIdeaIntoAPageAndTheCardEmpties() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Carnival in Salvador")
        let send = app.buttons["ideaCard.submit"]
        XCTAssertTrue(send.isEnabled)
        send.tap()

        XCTAssertTrue(element(app, "page.editor").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Draft ready'")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(element(app, "page.titleField").value as? String, "Carnival in Salvador")
        app.buttons["page.backButton"].tap()
        // It is a script in the library now, and the card starts empty.
        XCTAssertTrue(app.staticTexts["Carnival in Salvador"].waitForExistence(timeout: 5))
        XCTAssertNotEqual(element(app, "ideaCard.field").value as? String, "Carnival in Salvador")
    }

    /// The same card, with the same chips, when there are scripts.
    func testTheSameCardWorksOverTheScriptList() {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["scripts.newButton"].exists)
        for chip in ["platformChip", "voiceChip", "formatChip"] {
            XCTAssertTrue(app.buttons["ideaCard.\(chip)"].exists, chip)
        }
        field.tap()
        field.typeText("A day in my life")
        XCTAssertEqual(field.value as? String, "A day in my life")
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(element(app, "page.editor").waitForExistence(timeout: 15))
    }

    // MARK: - Write in my voice

    /// "✦ My Cue Voice · Set up" opens the four questions; "Not now" changes nothing and keeps the idea;
    /// answered, the idea is written and the script is the preview of the voice.
    func testMyCueVoiceAsksFourQuestionsAndTheScriptIsThePreview() {
        let app = CueApp.launch(seeded: false)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Carnival in Salvador")

        let chip = app.buttons["ideaCard.voiceChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.value as? String, "Set up")
        chip.tap()
        XCTAssertTrue(element(app, "voiceSetup.sheet").waitForExistence(timeout: 5))
        // Not now: the chip still says Set up and the idea is kept.
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.value as? String, "Set up")
        XCTAssertEqual(field.value as? String, "Carnival in Salvador")

        // 01 · the kind of creator (Continue waits for a pick). 02 · topics. 03 · audience. 04 · tone.
        chip.tap()
        XCTAssertTrue(app.buttons["voiceSetup.role.personal"].waitForExistence(timeout: 5))
        let next = app.buttons["voiceSetup.saveButton"]
        XCTAssertTrue(next.exists)
        XCTAssertFalse(next.isEnabled)
        app.buttons["voiceSetup.role.personal"].tap()
        XCTAssertTrue(next.isEnabled)
        next.tap()
        XCTAssertTrue(app.buttons["voiceSetup.niche.lifestyle"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled)
        app.buttons["voiceSetup.niche.lifestyle"].tap()
        next.tap()
        XCTAssertTrue(app.buttons["voiceSetup.audience.genZ"].waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled)
        app.buttons["voiceSetup.audience.genZ"].tap()
        next.tap()
        XCTAssertTrue(app.buttons["voiceSetup.tone.funny"].waitForExistence(timeout: 5))
        app.buttons["voiceSetup.tone.funny"].tap()
        // With an idea on the card, the last question writes it.
        XCTAssertEqual(next.label, "✦ Write my script")
        next.tap()

        // The script is the preview: it can be compared with the one without the voice, and approved.
        XCTAssertTrue(element(app, "page.voicePreview").waitForExistence(timeout: 15))
        app.buttons["page.voice.without"].tap()
        app.buttons["page.voice.mine"].tap()
        app.buttons["page.voice.approve"].tap()
        XCTAssertFalse(element(app, "page.voicePreview").waitForExistence(timeout: 2))
        app.buttons["page.backButton"].tap()
        // The chip shows how much of the creator Cue knows now (Essentials: 4 × 15%).
        XCTAssertEqual(app.buttons["ideaCard.voiceChip"].value as? String, "60%")
    }

    /// Set up, the chip shows the voice's strength and opens the questions again, filled in. (The voice's on/off switch is
    /// on Profile, not on the card.)
    func testTheVoiceChipShowsTheStrengthOnceItIsSet() {
        let app = CueApp.launch(seeded: false)
        let chip = app.buttons["ideaCard.voiceChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        app.buttons["voiceSetup.skipRole"].tap()
        app.buttons["voiceSetup.niche.tech"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.audience.simple"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.tone.casual"].tap()
        // No idea waiting: the last button just says Done.
        XCTAssertEqual(app.buttons["voiceSetup.saveButton"].label, "Done")
        app.buttons["voiceSetup.saveButton"].tap()
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        // The kind of creator was skipped: topics, audience and tone are 3 × 15%.
        XCTAssertEqual(chip.value as? String, "45%")
        XCTAssertFalse(app.switches["ideaCard.voiceToggle"].exists)

        // Tapping the chip opens My Cue Voice (9.3): the three layers, each row with its own sheet.
        chip.tap()
        XCTAssertTrue(element(app, "voicePage").waitForExistence(timeout: 5))
        app.buttons["voicePage.done"].tap()
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.value as? String, "45%")
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
        // Nothing written yet: the arrow asks for ideas ("Need an idea?"). Once listening it is off.
        XCTAssertTrue(send.isEnabled)
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
        XCTAssertFalse(app.buttons["page.backButton"].exists)
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
        app.cueTabBar.buttons.element(boundBy: 1).tap()
        app.cueTabBar.buttons.element(boundBy: 0).tap()
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

        app.buttons["ideaCard.voiceChip"].tap()
        XCTAssertTrue(element(app, "voiceSetup.sheet").waitForExistence(timeout: 10))
        app.buttons["sheet.closeButton"].tap()

        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertEqual(field.value as? String, "a video about my morning coffee routine")
        XCTAssertFalse(element(app, "ideaCard.dictationStatus").exists)
        XCTAssertEqual(app.buttons["ideaCard.dictate"].label, "Dictate your idea")
        XCTAssertEqual(app.buttons["ideaCard.voiceChip"].value as? String, "Set up")
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
}
