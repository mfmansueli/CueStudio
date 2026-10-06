//
//  VoiceV29UITests.swift
//  Cue StudioUITests
//

import XCTest

/// v29 · phase 8: My Cue Voice on Profile (9.1) and its full page (9.3), the validations of 04 · F9 and the nudges. Pictures
/// are saved when `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` is set.
@MainActor
final class VoiceV29UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Profile with the four setup questions answered (the minimum voice).
    private func setUpVoice(ai: CueApp.AIMode = .stub, animations: Bool = false, extraArguments: [String] = []) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, ai: ai, animations: animations, extraArguments: extraArguments)
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let setUp = app.buttons["profile.setUpVoiceButton"]
        XCTAssertTrue(setUp.waitForExistence(timeout: 5))
        setUp.tap()
        app.buttons["voiceSetup.skipRole"].tap()
        app.buttons["voiceSetup.niche.food"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.audience.simple"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.tone.casual"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        XCTAssertTrue(element(app, "profile.voiceSentence").waitForExistence(timeout: 5))
        return app
    }

    private func openVoicePage(_ app: XCUIApplication) {
        let edit = app.buttons["profile.editVoice"]
        app.scroll(to: edit)
        edit.tap()
        XCTAssertTrue(element(app, "voicePage").waitForExistence(timeout: 5))
    }

    func testTheProfileCardShowsTheMeterTheSentenceAndTheNextQuestion() {
        let app = setUpVoice()
        XCTAssertTrue(element(app, "voice.meter").exists)
        XCTAssertTrue(element(app, "profile.voiceSentence").exists)
        XCTAssertTrue(element(app, "profile.voiceNext").exists)
        capture(app, "9.1_profile_voice")
    }

    func testTheFullPageListsTheThreeLayersAndWhatCueSends() {
        let app = setUpVoice()
        openVoicePage(app)
        for row in ["role", "topics", "audience", "tone", "style", "formats", "openings", "endings", "phrases", "avoid", "reach", "examples"] {
            let element = element(app, "voicePage.row.\(row)")
            app.scroll(to: element)
            XCTAssertTrue(element.exists, row)
        }
        let brief = element(app, "voicePage.brief")
        app.scroll(to: brief)
        XCTAssertTrue(brief.exists)
        capture(app, "9.3_my_cue_voice")
    }

    /// F9: a typo asks "Did you mean…", a blocked word is refused, a repeat says "Already added.".
    func testFreeTextIsValidated() {
        // The "Saved" shows for 0.9 s before the sheet closes; without the closing animation it can be gone before the test looks.
        let app = setUpVoice(animations: true)
        openVoicePage(app)
        let row = element(app, "voicePage.row.endings")
        app.scroll(to: row)
        row.tap()
        // "+ Something else" is below the five endings; the field comes up with it.
        app.swipeUp()
        let somethingElse = element(app, "voice.somethingElse")
        XCTAssertTrue(somethingElse.waitForExistence(timeout: 5))
        somethingElse.tap()
        let field = element(app, "voice.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Save thsi")
        app.buttons["voice.add"].tap()
        XCTAssertTrue(app.buttons["voice.typo.use"].waitForExistence(timeout: 5))
        capture(app, "9.3_validation_typo")
        // A blocked word is refused.
        field.tap()
        for _ in 0..<9 { field.typeText(XCUIKeyboardKey.delete.rawValue) }
        field.typeText("holy shit")
        app.buttons["voice.add"].tap()
        XCTAssertTrue(app.staticTexts["Apple Intelligence can’t use this word."].waitForExistence(timeout: 5))
        capture(app, "9.3_validation_blocked")
        // The typo is used: it is saved.
        field.tap()
        for _ in 0..<9 { field.typeText(XCUIKeyboardKey.delete.rawValue) }
        field.typeText("Save thsi")
        app.buttons["voice.add"].tap()
        app.buttons["voice.typo.use"].tap()
        XCTAssertTrue(element(app, "voice.saved").waitForExistence(timeout: 5))
    }

    /// F9 · the tip on Scripts asks one question at a time (the sample takes were exported, so "Where do you post most?" is pulled to the
    /// front), says "Saved" and offers one more.
    func testTheTipOnScriptsAsksOneQuestionAtATime() {
        let app = setUpVoice(extraArguments: ["-uiTestVoiceTip"])
        app.cueTabBar.buttons["Scripts"].tap()
        let open = app.buttons.matching(NSPredicate(format: "label CONTAINS 'One quick question'")).firstMatch
        XCTAssertTrue(open.waitForExistence(timeout: 15))
        capture(app, "9.1_tip")
        open.tap()
        XCTAssertTrue(app.staticTexts["Where do you post most?"].waitForExistence(timeout: 5))
        element(app, "voice.option.tiktok").tap()
        XCTAssertTrue(element(app, "voice.saved").waitForExistence(timeout: 5))
        element(app, "voice.more").tap()
        // The next question replaces it.
        let old = app.staticTexts["Where do you post most?"]
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: old)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(app.buttons["sheet.closeButton"].exists)
    }

    /// F9 · no AI: the page says it needs Apple Intelligence and the data stays editable; no tips.
    func testWithoutAppleIntelligenceThePageSaysSoAndStaysEditable() {
        let app = setUpVoice(ai: .none)
        openVoicePage(app)
        XCTAssertTrue(element(app, "voicePage.needsAI").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "voice.tip").exists)
        let row = element(app, "voicePage.row.openings")
        app.scroll(to: row)
        row.tap()
        XCTAssertTrue(element(app, "voice.sheet.openings").waitForExistence(timeout: 5))
        capture(app, "9.3_no_ai")
    }
}
