//
//  RecorderV29UITests.swift
//  Cue StudioUITests
//

import XCTest

/// The recorder (v29 · 5.2) with a stand-in camera (`-uiTestDemoCamera`: the Simulator has none): the whole bar when idle, the compact
/// one while recording, the box that shrinks and a tap that brings the whole bar back (Studio is in `StudioUITests`).
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

    func testSelfieShowsTheWholeBarThenTheCompactOneWhileRecordingAndATapBringsItBack() throws {
        let app = launchRecorder()
        XCTAssertFalse(element(app, "prompter.compactBar").exists)
        let scrollMode = app.segmentedControls["prompter.scrollMode"]
        XCTAssertTrue(scrollMode.buttons["Voice"].exists && scrollMode.buttons["Steady"].exists)
        try capture(app, "5.2_idle")
        let box = element(app, "prompter.text")
        let idleWidth = box.frame.width

        app.buttons["prompter.recordButton"].tap()
        XCTAssertTrue(element(app, "prompter.compactBar").waitForExistence(timeout: 12))
        XCTAssertTrue(element(app, "prompter.recordingClock").exists)
        XCTAssertTrue(element(app, "prompter.modeChip").exists)
        XCTAssertFalse(app.segmentedControls["prompter.scrollMode"].buttons["Voice"].exists, "the mode switch goes with the whole bar")
        XCTAssertLessThan(box.frame.width, idleWidth, "the box shrinks while recording")
        try capture(app, "5.2_recording_compact")

        // A tap on the screen brings the whole bar back for a few seconds; then it is compact again.
        element(app, "prompter.showControlsArea").tap()
        XCTAssertTrue(app.segmentedControls["prompter.scrollMode"].buttons["Voice"].waitForExistence(timeout: 3))
        try capture(app, "5.2_recording_peek")
        XCTAssertTrue(element(app, "prompter.compactBar").waitForExistence(timeout: 8))

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
