//
//  VoiceTipUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The My Cue Voice tip above the Scripts dock (04 §F9, 08 §6): it comes with its question, opens the sheet, says "Saved · voice nn%" and
/// offers one more; a closed single answer is given with one tap on the tip; its ✕ is a dismissal. `-uiTestVoiceTip` opens the tip's gates
/// (a second day, a script, the wait and the caps).
@MainActor
final class VoiceTipUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// The tip's own button (its words), since the tip's container carries the identifier.
    private func openTip(_ app: XCUIApplication) {
        let open = app.buttons.matching(NSPredicate(format: "label CONTAINS 'One quick question'")).firstMatch
        XCTAssertTrue(open.exists(within: 5), "No tip to open")
        open.tap()
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
        // The hierarchy beside it, for `tools/contrast/audit.py`.
        try app.debugDescription.write(to: directory.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    func testTheTipAsksOneQuestionAndOffersOneMore() throws {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestVoiceTip"])
        let tip = element(app, "voice.tip")
        XCTAssertTrue(tip.exists(within: 15), "No tip")
        try capture(app, "voice_tip")
        openTip(app)

        // The first question of an empty voice in English is who's watching (no grammar to ask), then how much they know.
        try capture(app, "voice_question_audience")
        XCTAssertTrue(element(app, "voice.sheet.audience").exists(within: 5))
        element(app, "voice.option.parents").tap()
        element(app, "voice.option.some").tap()
        let saved = element(app, "voice.saved")
        XCTAssertTrue(saved.exists(within: 5))
        XCTAssertTrue(saved.label.contains("10%"), saved.label)
        try capture(app, "voice_saved")

        element(app, "voice.more").tap()
        XCTAssertTrue(element(app, "voice.sheet.role").exists(within: 5))
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(app.buttons["scripts.newButton"].exists(within: 5))
    }

    func testClosingTheTipIsADismissal() {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestVoiceTip"])
        let tip = element(app, "voice.tip")
        XCTAssertTrue(tip.exists(within: 15))
        app.buttons["Close tip"].tap()
        let gone = NSPredicate(format: "exists == false")
        XCTAssertTrue(tip.matches(gone, within: 5))
    }

    func testAMultipleAnswerQuestionHasSaveAndNoneOfThese() {
        // The "Saved" shows for 0.9 s before the sheet closes; without the closing animation it can be gone before the test looks.
        let app = CueApp.launch(seeded: false, animations: true, extraArguments: ["-uiTestVoiceTip"])
        XCTAssertTrue(element(app, "voice.tip").exists(within: 15))
        openTip(app)
        element(app, "voice.option.parents").tap()
        element(app, "voice.option.some").tap()
        element(app, "voice.more").tap()
        element(app, "voice.option.personal").tap()
        element(app, "voice.more").tap()
        XCTAssertTrue(element(app, "voice.sheet.topics").exists(within: 5))
        element(app, "voice.option.fitness").tap()
        element(app, "voice.option.food").tap()
        XCTAssertTrue(app.buttons["voice.sheet.save"].exists)
        // "+ Something else" and "None of these" close the list, below the topics.
        app.scroll(to: element(app, "voice.sheet.none"))
        XCTAssertTrue(element(app, "voice.somethingElse").exists)
        app.buttons["voice.sheet.save"].tap()
        XCTAssertTrue(element(app, "voice.saved").exists(within: 5))
    }

    /// The owner's item 13: where the script language marks it, the first tip asks how scripts write the creator, answered with one tap on
    /// the tip; the tip goes, and I am › Write me as shows the choice.
    func testTheGrammarIsAnsweredWithOneTapOnTheTip() throws {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestVoiceTip", "-uiTestScriptLanguage", "pt-BR"])
        // TipKit names every control inside a tip "TipView": the answers are found by their words, inside the tip.
        let tip = element(app, "voice.tip")
        let feminine = tip.buttons["Feminine"]
        XCTAssertTrue(feminine.exists(within: 15), "No one-tap tip")
        // The tip's body is one button that says the question and its line.
        let question = app.buttons.matching(NSPredicate(format: "label CONTAINS 'How should scripts write you?'")).firstMatch
        XCTAssertTrue(question.exists)
        XCTAssertTrue(question.label.contains("One tap"), question.label)
        XCTAssertTrue(tip.buttons["Masculine"].exists)
        XCTAssertTrue(tip.buttons["No gender"].exists)
        try capture(app, "voice_tip_one_tap")
        feminine.tap()

        let gone = NSPredicate(format: "exists == false")
        XCTAssertTrue(feminine.matches(gone, within: 5), "The tip stays after the answer")
        XCTAssertFalse(question.exists)
        // No sheet opened.
        XCTAssertFalse(element(app, "voice.sheet.speakerGender").exists)

        let tab = app.cueTabBar.buttons["Profile"]
        tab.tap()
        app.buttons["profile.setUpVoiceButton"].tap()
        let chosen = app.buttons["voice.speakerGender.feminine"]
        app.scroll(to: chosen)
        XCTAssertTrue(chosen.exists)
        XCTAssertTrue(chosen.isSelected, "Write me as doesn't show Feminine")
    }
}
