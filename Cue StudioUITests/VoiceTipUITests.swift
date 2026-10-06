//
//  VoiceTipUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The My Cue Voice tip above the Scripts dock (04 §F9, 08 §6): it comes with its question, opens the sheet, says "Saved · voice nn%" and
/// offers one more; its ✕ is a dismissal. `-uiTestVoiceTip` opens the tip's gates (a second day, a script, the wait and the caps).
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
        XCTAssertTrue(open.waitForExistence(timeout: 5), "No tip to open")
        open.tap()
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    func testTheTipAsksOneQuestionAndOffersOneMore() throws {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestVoiceTip"])
        let tip = element(app, "voice.tip")
        XCTAssertTrue(tip.waitForExistence(timeout: 15), "No tip")
        try capture(app, "voice_tip")
        openTip(app)

        // The first question of an empty voice is the kind of creator.
        try capture(app, "voice_question_role")
        XCTAssertTrue(element(app, "voice.sheet.role").waitForExistence(timeout: 5))
        element(app, "voice.option.personal").tap()
        let saved = element(app, "voice.saved")
        XCTAssertTrue(saved.waitForExistence(timeout: 5))
        XCTAssertTrue(saved.label.contains("10%"), saved.label)
        try capture(app, "voice_saved")

        element(app, "voice.more").tap()
        XCTAssertTrue(element(app, "voice.sheet.topics").waitForExistence(timeout: 5))
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(app.buttons["scripts.newButton"].waitForExistence(timeout: 5))
    }

    func testClosingTheTipIsADismissal() {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestVoiceTip"])
        let tip = element(app, "voice.tip")
        XCTAssertTrue(tip.waitForExistence(timeout: 15))
        app.buttons["Close tip"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: tip)
        waitForExpectations(timeout: 5)
    }

    func testAMultipleAnswerQuestionHasSaveAndNoneOfThese() {
        // The "Saved" shows for 0.9 s before the sheet closes; without the closing animation it can be gone before the test looks.
        let app = CueApp.launch(seeded: false, animations: true, extraArguments: ["-uiTestVoiceTip"])
        XCTAssertTrue(element(app, "voice.tip").waitForExistence(timeout: 15))
        openTip(app)
        element(app, "voice.option.personal").tap()
        element(app, "voice.more").tap()
        XCTAssertTrue(element(app, "voice.sheet.topics").waitForExistence(timeout: 5))
        element(app, "voice.option.fitness").tap()
        element(app, "voice.option.food").tap()
        XCTAssertTrue(app.buttons["voice.sheet.save"].exists)
        // "+ Something else" and "None of these" close the list, below the topics.
        for _ in 0..<4 where !element(app, "voice.somethingElse").exists { app.swipeUp() }
        XCTAssertTrue(element(app, "voice.somethingElse").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "voice.sheet.none").exists)
        app.buttons["voice.sheet.save"].tap()
        XCTAssertTrue(element(app, "voice.saved").waitForExistence(timeout: 5))
    }
}
