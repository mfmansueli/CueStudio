//
//  RecorderFramingUITests.swift
//  Cue StudioUITests
//

import XCTest

/// What the Selfie recorder shows of the camera image: the whole recorded frame every time the camera opens, and "Fill the screen" as a choice
/// that lasts only until the recorder closes. `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` saves a picture of each state (the safe zone included).
@MainActor
final class RecorderFramingUITests: XCTestCase {
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

    private func openRecorder(_ app: XCUIApplication) {
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        XCTAssertTrue(app.buttons["prompter.recordButton"].waitForExistence(timeout: 10))
    }

    /// The "Fill the screen" switch in the camera settings (the sheet scrolls to it).
    private func fillSwitch(_ app: XCUIApplication) -> XCUIElement {
        app.buttons["prompter.cameraSettingsButton"].tap()
        let toggle = app.switches.matching(NSPredicate(format: "label BEGINSWITH 'Fill the screen'")).firstMatch
        if !toggle.waitForExistence(timeout: 5) {
            let switches = app.switches.allElementsBoundByIndex.map(\.label)
            let texts = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.contains("Fill") || $0.contains("Grid") || $0.contains("Frame") }
            XCTFail("No Fill the screen switch in the camera settings. Switches: \(switches). Texts: \(texts). Sheets: \(app.sheets.count)")
        }
        // Short drags until the row clears the sheet's header (Camera | Recording · Done) and the bottom edge: a long swipe leaves it under the header.
        let headerBottom = app.buttons["Done"].firstMatch.frame.maxY + 12
        for _ in 0..<10 {
            let frame = toggle.frame
            let drag: CGFloat
            if frame.minY < headerBottom {
                drag = 120
            } else if frame.maxY > app.frame.maxY - 80 {
                drag = -120
            } else {
                break
            }
            let start = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: drag)))
        }
        return toggle
    }

    private func closeSheet(_ app: XCUIApplication) {
        // The sheet's own button; the recorder's "Close" (the X at the top) would leave the recorder.
        let done = app.buttons["Done"].firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 3))
        done.tap()
        XCTAssertTrue(app.buttons["prompter.recordButton"].waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["Done"].firstMatch.waitForExistence(timeout: 1.5), "The camera settings stayed open")
    }

    func testTheCameraOpensShowingTheWholeFrameAndFillingLastsOnlyUntilTheRecorderCloses() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDemoCamera"])
        openRecorder(app)
        try capture(app, "framing_1_whole_frame")

        var toggle = fillSwitch(app)
        XCTAssertEqual(toggle.value as? String, "0", "The camera did not open showing the whole frame")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        XCTAssertEqual(toggle.value as? String, "1")
        closeSheet(app)
        try capture(app, "framing_2_fill_the_screen")

        // Out of the recorder and back in: the whole frame again.
        app.buttons["prompter.closeButton"].tap()
        openRecorder(app)
        toggle = fillSwitch(app)
        XCTAssertEqual(toggle.value as? String, "0", "Filling the screen was remembered")
        closeSheet(app)
        try capture(app, "framing_3_whole_frame_again")
    }
}
