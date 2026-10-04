//
//  RecorderV29UITests.swift
//  Cue StudioUITests
//

import XCTest

/// The recorder (v29 · 5.2 and 5.3) with a stand-in camera (`-uiTestDemoCamera`: the Simulator has none): the whole bar when idle, the compact
/// one while recording, the box that shrinks, a tap that brings the whole bar back, Studio with its thumbnail. 
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

    private func launchRecorder(studio: Bool = false) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDemoCamera"])
        if studio {
            app.openStudio(titled: "Oat & Co. — sponsored read")
        } else {
            let record = app.buttons["row.recordButton"].firstMatch
            XCTAssertTrue(record.waitForExistence(timeout: 15))
            record.tap()
        }
        XCTAssertTrue(app.buttons["prompter.recordButton"].waitForExistence(timeout: 10))
        return app
    }

    func testSelfieShowsTheWholeBarThenTheCompactOneWhileRecordingAndATapBringsItBack() throws {
        let app = launchRecorder()
        XCTAssertFalse(element(app, "prompter.compactBar").exists)
        XCTAssertTrue(app.buttons["prompter.scrollMode.voice"].exists && app.buttons["prompter.scrollMode.steady"].exists)
        try capture(app, "5.2_idle")
        let box = element(app, "prompter.text")
        let idleWidth = box.frame.width

        app.buttons["prompter.recordButton"].tap()
        XCTAssertTrue(element(app, "prompter.compactBar").waitForExistence(timeout: 12))
        XCTAssertTrue(element(app, "prompter.recordingClock").exists)
        XCTAssertTrue(element(app, "prompter.modeChip").exists)
        XCTAssertFalse(app.buttons["prompter.scrollMode.voice"].exists, "the mode switch goes with the whole bar")
        XCTAssertLessThan(box.frame.width, idleWidth, "the box shrinks while recording")
        try capture(app, "5.2_recording_compact")

        // A tap on the screen brings the whole bar back for a few seconds; then it is compact again.
        element(app, "prompter.showControlsArea").tap()
        XCTAssertTrue(app.buttons["prompter.scrollMode.voice"].waitForExistence(timeout: 3))
        try capture(app, "5.2_recording_peek")
        XCTAssertTrue(element(app, "prompter.compactBar").waitForExistence(timeout: 8))

        app.buttons["prompter.recordButton"].tap()
        XCTAssertTrue(app.buttons["review.shareButton"].waitForExistence(timeout: 20) || element(app, "review.takeLabel").waitForExistence(timeout: 20))
    }

    func testStudioRecordsWithTheRearCameraThumbnailAndTheSameCompactBar() throws {
        let app = launchRecorder(studio: true)
        XCTAssertTrue(element(app, "prompter.studioPreview").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["prompter.scrollMode.voice"].exists)
        // The thumbnail never covers the text: it sits to the right of it.
        let text = element(app, "prompter.text")
        if text.exists { XCTAssertLessThanOrEqual(text.frame.maxX, element(app, "prompter.studioPreview").frame.minX + 1) }
        try capture(app, "5.3_studio_idle")
        app.buttons["prompter.recordButton"].tap()
        XCTAssertTrue(element(app, "prompter.compactBar").waitForExistence(timeout: 12))
        try capture(app, "5.3_studio_recording")
        app.buttons["prompter.recordButton"].tap()
        XCTAssertTrue(app.buttons["review.shareButton"].waitForExistence(timeout: 20) || element(app, "review.takeLabel").waitForExistence(timeout: 20))
    }

    func testThereIsNoHideControlsButton() {
        let app = launchRecorder()
        XCTAssertFalse(app.buttons["Hide controls"].exists)
        XCTAssertFalse(app.buttons["prompter.hideControlsButton"].exists)
    }
}
