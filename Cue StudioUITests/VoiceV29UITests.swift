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
        app.buttons["voiceSetup.audience.parents"].tap()
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

    func testTheFullPageListsTheThreeLayersAndTwoButtons() {
        let app = setUpVoice()
        openVoicePage(app)
        for row in [
            "role", "topics", "audience", "watch", "tone", "style", "formats", "openings", "endings", "goals", "phrases", "avoid", "reach", "examples",
        ] {
            let element = element(app, "voicePage.row.\(row)")
            app.scroll(to: element)
            XCTAssertTrue(element.exists, row)
        }
        // The page has no fine-tune link, no brief of its own and no reset: the two buttons under the list take their place.
        XCTAssertFalse(element(app, "voicePage.fineTune").exists)
        XCTAssertFalse(element(app, "voicePage.brief").exists)
        XCTAssertFalse(element(app, "voicePage.reset").exists)
        let preview = element(app, "voicePage.preview")
        app.scroll(to: preview)
        XCTAssertTrue(preview.exists)
        XCTAssertTrue(element(app, "voicePage.sends").exists)
        capture(app, "9.3_my_cue_voice")
    }

    /// "What Cue sends": the voice as Apple Intelligence reads it, how much of the 1200 characters it takes, and the way back to the four questions.
    func testWhatCueSendsShowsTheBriefAndLetsTheCreatorAnswerAgain() {
        let app = setUpVoice()
        openVoicePage(app)
        let sends = element(app, "voicePage.sends")
        app.scroll(to: sends)
        sends.tap()
        XCTAssertTrue(element(app, "voice.sends").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "voice.sends.brief").exists)
        XCTAssertTrue(element(app, "voice.sends.meter").exists)
        capture(app, "9.3_what_cue_sends")
        let again = element(app, "voice.sends.again")
        app.scroll(to: again)
        again.tap()
        XCTAssertTrue(element(app, "voiceSetup.sheet").waitForExistence(timeout: 5))
    }

    /// "Does this sound like you?": the same sample two ways, Adjust inside the sheet, Sounds like me with its toast.
    func testThePreviewComparesTheVoiceAdjustsAndLearns() {
        let app = setUpVoice()
        openVoicePage(app)
        let preview = element(app, "voicePage.preview")
        app.scroll(to: preview)
        preview.tap()
        XCTAssertTrue(element(app, "voice.preview").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "voice.preview.card").exists)
        capture(app, "9.3_preview")
        element(app, "voice.preview.adjust").tap()
        XCTAssertTrue(element(app, "voiceSetup.tone.casual").waitForExistence(timeout: 5), "the tone editor is in the same sheet")
        element(app, "voice.preview.done").tap()
        XCTAssertTrue(element(app, "voice.preview.soundsLikeMe").waitForExistence(timeout: 5))
        element(app, "voice.preview.soundsLikeMe").tap()
        XCTAssertTrue(app.staticTexts["Learned from this script"].waitForExistence(timeout: 5))
    }

    /// F9: a typo asks "Did you mean…", a blocked word is refused, a repeat says "Already added.".
    func testFreeTextIsValidated() {
        let app = setUpVoice()
        openVoicePage(app)
        let row = element(app, "voicePage.row.endings")
        app.scroll(to: row)
        row.tap()
        XCTAssertTrue(element(app, "voice.editor.formats").waitForExistence(timeout: 5))
        let field = app.textFields["voice.endings.field"]
        app.scroll(to: field)
        field.tap()
        field.typeText("Save thsi")
        app.buttons["voice.endings.field.add"].tap()
        XCTAssertTrue(app.buttons["voice.typo.use"].waitForExistence(timeout: 5))
        capture(app, "9.3_validation_typo")
        // A blocked word is refused.
        field.tap()
        for _ in 0..<9 { field.typeText(XCUIKeyboardKey.delete.rawValue) }
        field.typeText("holy shit")
        app.buttons["voice.endings.field.add"].tap()
        XCTAssertTrue(app.staticTexts["Apple Intelligence can’t use this word."].waitForExistence(timeout: 5))
        capture(app, "9.3_validation_blocked")
        // The typo is used: the offered ending is now chosen.
        field.tap()
        for _ in 0..<9 { field.typeText(XCUIKeyboardKey.delete.rawValue) }
        field.typeText("Save thsi")
        app.buttons["voice.endings.field.add"].tap()
        app.buttons["voice.typo.use"].tap()
        XCTAssertTrue(app.buttons["voice.endings.Save this"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["voice.endings.Save this"].isSelected)
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
        XCTAssertTrue(element(app, "voice.editor.formats").waitForExistence(timeout: 5))
        capture(app, "9.3_no_ai")
    }
}
