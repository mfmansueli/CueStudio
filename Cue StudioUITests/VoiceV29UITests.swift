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

    private func scroll(_ app: XCUIApplication, to element: XCUIElement) {
        var swipes = 0
        while !element.isHittable, swipes < 8 {
            app.swipeUp()
            swipes += 1
        }
    }

    /// Profile with the four setup questions answered (the minimum voice).
    private func setUpVoice(ai: CueApp.AIMode = .stub) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, ai: ai)
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
        XCTAssertTrue(element(app, "profile.voiceSample").waitForExistence(timeout: 5))
        return app
    }

    private func openVoicePage(_ app: XCUIApplication) {
        let edit = app.buttons["profile.editVoice"]
        scroll(app, to: edit)
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
        for row in ["role", "niche", "audience", "tone", "endings", "openings", "phrases", "formats", "swearing", "examples"] {
            let element = element(app, "voicePage.row.\(row)")
            scroll(app, to: element)
            XCTAssertTrue(element.exists, row)
        }
        let brief = element(app, "voicePage.brief")
        scroll(app, to: brief)
        XCTAssertTrue(brief.exists)
        capture(app, "9.3_my_cue_voice")
    }

    /// F9: a typo asks "Did you mean…", a blocked word is refused, a repeat says "Already added." and the limit says Max.
    func testFreeTextIsValidated() {
        let app = setUpVoice()
        openVoicePage(app)
        let row = element(app, "voicePage.row.endings")
        scroll(app, to: row)
        row.tap()
        let field = app.textFields["voice.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Save thsi")
        app.buttons["voice.add"].tap()
        XCTAssertTrue(app.buttons["voice.typo.use"].waitForExistence(timeout: 5))
        capture(app, "9.3_validation_typo")
        app.buttons["voice.typo.use"].tap()
        XCTAssertTrue(app.buttons.matching(identifier: "voice.option").matching(NSPredicate(format: "label == 'Save this'")).firstMatch.isSelected)
        // A repeat.
        field.tap()
        field.typeText("save this")
        app.buttons["voice.add"].tap()
        XCTAssertTrue(app.staticTexts["Already added."].waitForExistence(timeout: 5))
        // A blocked word.
        field.tap()
        field.typeText("holy shit")
        app.buttons["voice.add"].tap()
        XCTAssertTrue(app.staticTexts["Apple Intelligence can’t use this word."].waitForExistence(timeout: 5))
        capture(app, "9.3_validation_blocked")
    }

    /// F9 · nudge: one question on Scripts; "Not now" holds it back, "None of these" retires it.
    func testTheNudgeOnScriptsAsksOneQuestionAtATime() {
        let app = setUpVoice()
        app.cueTabBar.buttons["Scripts"].tap()
        let nudge = element(app, "voice.nudge")
        scroll(app, to: nudge)
        XCTAssertTrue(nudge.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["How do you usually end a video?"].exists)
        capture(app, "9.1_nudge")
        app.buttons["voice.nudge.notNow"].tap()
        // The next question comes up in its place.
        XCTAssertTrue(app.staticTexts["How do you like to open?"].waitForExistence(timeout: 5))
        app.buttons["voice.nudge.none"].tap()
        XCTAssertTrue(app.staticTexts["What do you film most?"].waitForExistence(timeout: 5))
    }

    /// F9 · no AI: the page says it needs Apple Intelligence and the data stays editable; no nudges.
    func testWithoutAppleIntelligenceThePageSaysSoAndStaysEditable() {
        let app = setUpVoice(ai: .none)
        openVoicePage(app)
        XCTAssertTrue(element(app, "voicePage.needsAI").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "voice.nudge").exists)
        let row = element(app, "voicePage.row.openings")
        scroll(app, to: row)
        row.tap()
        XCTAssertTrue(app.buttons["voice.nudge.none"].exists == false)
        XCTAssertTrue(app.textFields["voice.field"].waitForExistence(timeout: 5))
        capture(app, "9.3_no_ai")
    }
}
