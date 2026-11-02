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
        try? app.debugDescription.write(to: directory.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Profile with the four setup questions answered (the minimum voice).
    private func setUpVoice(ai: CueApp.AIMode = .stub, animations: Bool = false, extraArguments: [String] = []) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, ai: ai, animations: animations, extraArguments: extraArguments)
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let setUp = app.buttons["profile.setUpVoiceButton"]
        XCTAssertTrue(setUp.exists(within: 5))
        setUp.tap()
        app.buttons["voiceSetup.skipRole"].tap()
        app.buttons["voiceSetup.niche.food"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.audience.parents"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.tone.casual"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        XCTAssertTrue(element(app, "profile.voiceSentence").exists(within: 5))
        return app
    }

    private func openVoicePage(_ app: XCUIApplication) {
        let edit = app.buttons["profile.editVoice"]
        app.scroll(to: edit)
        edit.tap()
        XCTAssertTrue(element(app, "voicePage").exists(within: 5))
    }

    func testTheProfileCardShowsTheMeterTheSentenceAndTheNextQuestion() {
        let app = setUpVoice()
        XCTAssertTrue(element(app, "voice.meter").exists)
        XCTAssertTrue(element(app, "profile.voiceSentence").exists)
        XCTAssertTrue(element(app, "profile.voiceNext").exists)
        capture(app, "9.1_profile_voice")
    }

    func testTheFullPageListsTheSectionsAndTwoButtons() {
        let app = setUpVoice()
        openVoicePage(app)
        capture(app, "9.3_my_cue_voice_top")
        for row in [
            "role", "audience", "watch", "reach", "topics", "formats", "goals", "tone", "style", "phrases", "openings", "endings", "notes", "avoid",
            "examples", "learned",
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

    /// "Also true about me" (the owner's item 7): a note added here shows on the page, and a tap on its ✕ takes it away.
    func testAlsoTrueAboutMeKeepsTheCreatorsOwnNotes() {
        let app = setUpVoice()
        openVoicePage(app)
        let row = element(app, "voicePage.row.notes")
        app.scroll(to: row)
        row.tap()
        let field = app.textFields["voice.notes.field"]
        XCTAssertTrue(field.exists(within: 5))
        field.tap()
        field.typeText("I film in my car\n")
        XCTAssertTrue(app.buttons["voice.note"].exists(within: 3))
        app.buttons["voice.editor.done"].tap()
        XCTAssertTrue(element(app, "voicePage.row.notes").label.contains("I film in my car"))
        element(app, "voicePage.row.notes").tap()
        app.buttons["voice.note.remove"].tap()
        XCTAssertFalse(app.buttons["voice.note"].exists)
    }

    /// "Stories and facts" (the owner's item 9): a moment said with the microphone lands in the field to read, Save keeps it, and the page counts it.
    func testAStorySaidWithTheMicrophoneIsKept() {
        let story = "I started filming in my car because it was the only quiet place"
        let app = setUpVoice(extraArguments: ["-uiTestDictation", "speech", "-uiTestDictationText", story])
        openVoicePage(app)
        let row = element(app, "voicePage.row.stories")
        app.scroll(to: row)
        row.tap()
        XCTAssertTrue(element(app, "voice.stories.intro").exists(within: 5))
        let microphone = app.buttons["voice.story.field.dictate"]
        microphone.tap()
        let field = element(app, "voice.story.field")
        XCTAssertTrue(field.matches(NSPredicate(format: "value CONTAINS 'quiet place'"), within: 10), "Nothing was heard")
        microphone.tap()
        let save = app.buttons["voice.story.field.save"]
        XCTAssertTrue(save.exists(within: 5))
        save.tap()
        XCTAssertTrue(app.staticTexts[story].exists(within: 3), "The story was not kept")
        capture(app, "voice_stories")
        app.buttons["voice.editor.done"].tap()
        XCTAssertTrue(element(app, "voicePage.row.stories").label.contains("1 of 5"))
    }

    /// The live example (the owner's item 1): picking an opening shows its line, and the next pick changes it.
    func testAnOpeningShowsItsLiveExample() {
        let app = setUpVoice()
        openVoicePage(app)
        let row = element(app, "voicePage.row.openings")
        app.scroll(to: row)
        row.tap()
        let question = app.buttons["voice.openings.Question"]
        app.scroll(to: question)
        question.tap()
        let example = element(app, "voice.openings.example")
        XCTAssertTrue(example.exists(within: 3))
        XCTAssertTrue(example.label.contains("Why do some mornings feel like a fight?"))
        app.buttons["voice.openings.POV"].tap()
        XCTAssertTrue(element(app, "voice.openings.example").label.contains("POV: you finally stopped losing your mornings."))
        capture(app, "voice_openings_example")
    }

    /// "What Cue sends": the voice as Apple Intelligence reads it, how much of the 1200 characters it takes, and the way back to the four questions.
    func testWhatCueSendsShowsTheBriefAndLetsTheCreatorAnswerAgain() {
        let app = setUpVoice()
        openVoicePage(app)
        let sends = element(app, "voicePage.sends")
        app.scroll(to: sends)
        sends.tap()
        XCTAssertTrue(element(app, "voice.sends").exists(within: 5))
        XCTAssertTrue(element(app, "voice.sends.brief").exists)
        XCTAssertTrue(element(app, "voice.sends.meter").exists)
        capture(app, "9.3_what_cue_sends")
        let cloud = element(app, "voice.sends.cloudBrief")
        app.scroll(to: cloud)
        XCTAssertTrue(cloud.isHittable)
        capture(app, "9.3_what_cue_sends_cloud")
        let again = element(app, "voice.sends.again")
        app.scroll(to: again)
        again.tap()
        XCTAssertTrue(element(app, "voiceSetup.sheet").exists(within: 5))
    }

    /// "Does this sound like you?": the same sample two ways, Adjust inside the sheet, Sounds like me with its toast.
    func testThePreviewComparesTheVoiceAdjustsAndLearns() {
        let app = setUpVoice()
        openVoicePage(app)
        let preview = element(app, "voicePage.preview")
        app.scroll(to: preview)
        preview.tap()
        XCTAssertTrue(element(app, "voice.preview").exists(within: 5))
        XCTAssertTrue(element(app, "voice.preview.card").exists)
        capture(app, "9.3_preview")
        element(app, "voice.preview.adjust").tap()
        XCTAssertTrue(element(app, "voiceSetup.tone.casual").exists(within: 5), "the tone editor is in the same sheet")
        element(app, "voice.preview.done").tap()
        XCTAssertTrue(element(app, "voice.preview.soundsLikeMe").exists(within: 5))
        element(app, "voice.preview.soundsLikeMe").tap()
        XCTAssertTrue(app.staticTexts["Saved · counts toward your voice"].exists(within: 5))
    }

    /// F9: a typo asks "Did you mean…", a blocked word is refused, a repeat says "Already added.".
    func testFreeTextIsValidated() {
        let app = setUpVoice()
        openVoicePage(app)
        let row = element(app, "voicePage.row.endings")
        app.scroll(to: row)
        row.tap()
        XCTAssertTrue(element(app, "voice.editor.formats").exists(within: 5))
        let field = app.textFields["voice.endings.field"]
        app.scroll(to: field)
        field.tap()
        field.typeText("Save thsi")
        app.buttons["voice.endings.field.add"].tap()
        XCTAssertTrue(app.buttons["voice.typo.use"].exists(within: 5))
        capture(app, "9.3_validation_typo")
        // A blocked word is refused.
        field.tap()
        for _ in 0..<9 { field.typeText(XCUIKeyboardKey.delete.rawValue) }
        field.typeText("holy shit")
        app.buttons["voice.endings.field.add"].tap()
        XCTAssertTrue(app.staticTexts["Apple Intelligence can’t use this word."].exists(within: 5))
        capture(app, "9.3_validation_blocked")
        // The typo is used: the offered ending is now chosen.
        field.tap()
        for _ in 0..<9 { field.typeText(XCUIKeyboardKey.delete.rawValue) }
        field.typeText("Save thsi")
        app.buttons["voice.endings.field.add"].tap()
        app.buttons["voice.typo.use"].tap()
        XCTAssertTrue(app.buttons["voice.endings.Save this"].exists(within: 5))
        XCTAssertTrue(app.buttons["voice.endings.Save this"].isSelected)
    }

    /// F9 · the tip on Scripts asks one question at a time (the sample takes were exported, so "Where do you post most?" is pulled to the
    /// front), says "Saved" and offers one more.
    /// "I am" asks how the words about the creator agree and how viewers are addressed (the owner's B8, 02/11/2026): both optional, the chosen
    /// gender lets go on a second tap (not chosen, never the masculine), informal is the default. In English they wait under "More questions"
    /// (the owner's item 8): they change nothing there.
    func testIAmAsksHowTheWordsAboutTheCreatorAgree() {
        let app = CueApp.launch(seeded: true, ai: .stub)
        openIAm(app)
        let more = app.buttons["voice.agreement.more"]
        app.scroll(to: more)
        XCTAssertFalse(app.buttons["voice.speakerGender.feminine"].exists, "English: folded")
        more.tap()
        let feminine = app.buttons["voice.speakerGender.feminine"]
        app.scroll(to: feminine)
        XCTAssertFalse(feminine.isSelected, "not chosen until the creator picks")
        feminine.tap()
        XCTAssertTrue(feminine.isSelected)
        feminine.tap()
        XCTAssertFalse(feminine.isSelected, "a second tap lets it go")
        let informal = app.buttons["voice.addressForm.informal"]
        let formal = app.buttons["voice.addressForm.formal"]
        app.scroll(to: formal)
        XCTAssertTrue(informal.isSelected, "informal is the default")
        formal.tap()
        XCTAssertTrue(formal.isSelected && !informal.isSelected)
        capture(app, "voice-i-am-agreement")
    }

    /// Scripts in Portuguese (Settings › Language & Region): both are asked in the open, with the language's own words as the example.
    func testIAmAsksAgreementOpenlyWhereTheScriptLanguageNeedsIt() {
        let app = CueApp.launch(seeded: true, ai: .stub, extraArguments: ["-uiTestScriptLanguage", "pt-BR"])
        openIAm(app)
        let feminine = app.buttons["voice.speakerGender.feminine"]
        app.scroll(to: feminine)
        XCTAssertTrue(feminine.exists)
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "“cansada”")).firstMatch.exists)
        XCTAssertTrue(app.buttons["voice.addressForm.formal"].exists)
        XCTAssertFalse(app.buttons["voice.agreement.more"].exists, "nothing folded in Portuguese")
    }

    private func openIAm(_ app: XCUIApplication) {
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        app.buttons["profile.setUpVoiceButton"].tap()
    }

    func testTheTipOnScriptsAsksOneQuestionAtATime() {
        let app = setUpVoice(extraArguments: ["-uiTestVoiceTip"])
        app.cueTabBar.buttons["Scripts"].tap()
        // The first export pulled where they post forward: a closed list, answered with one tap on the tip.
        // TipKit names every control inside a tip "TipView": the answer is found by its words, inside the tip.
        let tiktok = element(app, "voice.tip").buttons["TikTok"]
        XCTAssertTrue(tiktok.exists(within: 15))
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS 'Where do you post most?'")).firstMatch.exists)
        capture(app, "9.1_tip")
        tiktok.tap()
        let gone = NSPredicate(format: "exists == false")
        XCTAssertTrue(tiktok.matches(gone, within: 5))
        XCTAssertFalse(app.buttons["sheet.closeButton"].exists, "no sheet for a one-tap answer")
    }

    /// F9 · no AI: the page says it needs Apple Intelligence and the data stays editable; no tips.
    func testWithoutAppleIntelligenceThePageSaysSoAndStaysEditable() {
        let app = setUpVoice(ai: .none)
        openVoicePage(app)
        XCTAssertTrue(element(app, "voicePage.needsAI").exists(within: 5))
        XCTAssertFalse(element(app, "voice.tip").exists)
        let row = element(app, "voicePage.row.openings")
        app.scroll(to: row)
        row.tap()
        XCTAssertTrue(element(app, "voice.editor.formats").exists(within: 5))
        capture(app, "9.3_no_ai")
    }
}
