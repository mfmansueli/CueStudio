//
//  RecorderV29UITests.swift
//  Cue StudioUITests
//

import XCTest

/// The recorder (v29 · 5.2, v30 bar) with a stand-in camera (`-uiTestDemoCamera`: the Simulator has none): the whole bar when idle, one row
/// while recording and a tap that brings the whole bar back (Studio is in `StudioUITests`).
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` saves a picture of each state.
@MainActor
final class RecorderV29UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func launchRecorder() -> XCUIApplication {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDemoCamera"])
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        XCTAssertTrue(app.buttons["prompter.recordButton"].waitForExistence(timeout: 10))
        return app
    }

    /// v30: while a take records, the REC pill and its clock take the start of the navigation bar, and the controls gather into one row (the
    /// mode switch and the reading controls fold away); a tap on the picture brings them all back for a few seconds (`SelfieControlSheet`).
    func testSelfieShowsTheWholeBarThenOneRowWhileRecordingAndATapBringsItBack() throws {
        let app = launchRecorder()
        XCTAssertFalse(element(app, "prompter.recordingBadge").exists)
        XCTAssertFalse(element(app, "prompter.showControlsArea").exists)
        let scrollMode = app.descendants(matching: .any)["prompter.scrollMode"].firstMatch
        XCTAssertTrue(scrollMode.buttons["Voice"].exists && scrollMode.buttons["Steady"].exists)
        try capture(app, "5.2_idle")

        app.buttons["prompter.recordButton"].tap()
        XCTAssertTrue(element(app, "prompter.recordingBadge").waitForExistence(timeout: 12), "REC and the clock are in the bar")
        XCTAssertTrue(element(app, "prompter.showControlsArea").waitForExistence(timeout: 5), "the controls gather into one row")
        // Folded away with the reading controls: out of sight and out of reach.
        let voice = app.descendants(matching: .any)["prompter.scrollMode"].firstMatch.buttons["Voice"]
        let folded = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false OR hittable == false"), object: voice)
        XCTAssertEqual(XCTWaiter.wait(for: [folded], timeout: 3), .completed, "the mode switch goes with the reading controls")
        try capture(app, "5.2_recording_row")

        // A tap on the screen brings the whole bar back for a few seconds; then it is one row again.
        element(app, "prompter.showControlsArea").tap()
        let back = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == true AND hittable == true"), object: voice)
        XCTAssertEqual(XCTWaiter.wait(for: [back], timeout: 3), .completed, "the tap didn't bring the controls back")
        try capture(app, "5.2_recording_peek")
        XCTAssertTrue(element(app, "prompter.showControlsArea").waitForExistence(timeout: 8))

        app.buttons["prompter.recordButton"].tap()
        XCTAssertTrue(app.buttons["review.shareButton"].waitForExistence(timeout: 20) || element(app, "review.takeLabel").waitForExistence(timeout: 20))
    }

    /// The text box opens near the top of the screen, under the lens, not in the middle of it.
    func testTheBoxOpensNearTheTop() throws {
        let app = launchRecorder()
        let box = element(app, "prompter.text")
        XCTAssertTrue(box.waitForExistence(timeout: 5))
        XCTAssertLessThan(box.frame.minY, app.frame.height * 0.25, "the box starts in the top quarter")
        XCTAssertLessThan(box.frame.midY, app.frame.height * 0.5, "its middle is above the middle of the screen")
        try capture(app, "5.2_box_top")
    }

    func testThereIsNoHideControlsButton() {
        let app = launchRecorder()
        XCTAssertFalse(app.buttons["Hide controls"].exists)
        XCTAssertFalse(app.buttons["prompter.hideControlsButton"].exists)
    }
}
