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

        // The first question of an empty voice is what kind of creator they are (the owner, 03/11/2026): the long list with its search
        // and areas, saved with Save once a kind is picked; in English there is no grammar to ask, so who's watching comes next.
        try capture(app, "voice_question_role")
        XCTAssertTrue(element(app, "voice.sheet.role").exists(within: 5))
        let save = app.buttons["voice.sheet.save"]
        XCTAssertTrue(save.exists)
        XCTAssertFalse(save.isEnabled, "Save waits for a kind")
        element(app, "voiceSetup.role.area.lawMoney").tap()
        element(app, "voiceSetup.role.lawyer").tap()
        XCTAssertTrue(save.isEnabled)
        save.tap()
        let saved = element(app, "voice.saved")
        XCTAssertTrue(saved.exists(within: 5))
        XCTAssertTrue(saved.label.contains("%"), saved.label)
        try capture(app, "voice_saved")

        element(app, "voice.more").tap()
        XCTAssertTrue(element(app, "voice.sheet.audience").exists(within: 5))
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
        // What kind of creator is answered: the tip starts at who's watching.
        let app = CueApp.launch(seeded: false, animations: true, extraArguments: ["-uiTestVoiceTip", "-uiTestCreatorKind", "lifestyleCreator"])
        XCTAssertTrue(element(app, "voice.tip").exists(within: 15))
        openTip(app)
        element(app, "voice.option.parents").tap()
        element(app, "voice.option.some").tap()
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
    /// the tip; the tip goes, and the next question takes its place.
    func testTheGrammarIsAnsweredWithOneTapOnTheTip() throws {
        let app = CueApp.launch(
            seeded: false, extraArguments: ["-uiTestVoiceTip", "-uiTestScriptLanguage", "pt-BR", "-uiTestCreatorKind", "lifestyleCreator"]
        )
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
        // The answer counted: the next question, how to speak to viewers, takes the tip's place (one tap too). The kind of creator was
        // answered before (`-uiTestCreatorKind`), so My Cue Voice's setup no longer shows "Write me as": `VoiceTipByImpactTests` checks the
        // profile holds Feminine.
        XCTAssertTrue(tip.buttons["Informal"].exists(within: 10), "The next question didn't come")
        XCTAssertTrue(tip.buttons["Formal"].exists)
    }
}
