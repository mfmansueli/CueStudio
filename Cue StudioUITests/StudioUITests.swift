//
//  StudioUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Studio (v30) is only the prompter: no camera, no recording. It has the transport, the speed, the quick adjustments (Size, Line,
/// Margin, Mirror, Aa), the time left and a bar that puts itself away. `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` saves a picture of each state.
@MainActor
final class StudioUITests: XCTestCase {
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

    private func launchStudio() -> XCUIApplication {
        let app = CueApp.launch(seeded: true)
        app.openStudio(titled: "Oat & Co. — sponsored read")
        XCTAssertTrue(app.buttons["prompter.playButton"].waitForExistence(timeout: 10))
        return app
    }

    func testStudioHasNoCameraAndNothingToRecord() throws {
        let app = launchStudio()
        XCTAssertFalse(app.buttons["prompter.recordButton"].exists)
        XCTAssertFalse(element(app, "prompter.studioPreview").exists)
        XCTAssertFalse(app.buttons["prompter.cameraSettingsButton"].exists)
        XCTAssertFalse(element(app, "prompter.audioInputButton").exists)
        XCTAssertTrue(app.buttons["prompter.scrollMode.voice"].exists && app.buttons["prompter.scrollMode.steady"].exists)
        XCTAssertTrue(element(app, "prompter.speedSlider").exists)
        XCTAssertTrue(element(app, "studio.timeLeft").waitForExistence(timeout: 5))
        try capture(app, "studio_idle")
    }

    func testTheChipsOpenOneSliderAtATime() throws {
        let app = launchStudio()
        let size = app.buttons["studio.adjust.size"]
        XCTAssertTrue(size.exists)
        XCTAssertFalse(element(app, "studio.slider.size").exists)
        size.tap()
        XCTAssertTrue(element(app, "studio.slider.size").waitForExistence(timeout: 3))
        XCTAssertTrue(size.isSelected)
        try capture(app, "studio_size")

        app.buttons["studio.adjust.line"].tap()
        XCTAssertTrue(element(app, "studio.slider.line").waitForExistence(timeout: 3))
        XCTAssertFalse(element(app, "studio.slider.size").exists, "one slider at a time")

        app.buttons["studio.adjust.line"].tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: element(app, "studio.slider.line"))
        waitForExpectations(timeout: 3)
    }

    func testMirrorFlipsTheTextForTheGlass() {
        let app = launchStudio()
        let mirror = app.buttons["studio.adjust.mirror"]
        XCTAssertEqual(mirror.value as? String, "Off")
        mirror.tap()
        XCTAssertEqual(mirror.value as? String, "On")
        mirror.tap()
        XCTAssertEqual(mirror.value as? String, "Off")
    }

    func testTheBarPutsItselfAwayAndComesBack() throws {
        let app = launchStudio()
        app.buttons["studio.hideControls"].tap()
        let show = app.buttons["studio.showControls"]
        XCTAssertTrue(show.waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["prompter.playButton"].exists)
        try capture(app, "studio_bar_hidden")
        show.tap()
        XCTAssertTrue(app.buttons["prompter.playButton"].waitForExistence(timeout: 3))
    }

    /// Play from the top waits for the countdown set in Settings, so there is time to get in front of the other camera, then the text runs.
    func testPlayFromTheTopCountsDownThenPlays() throws {
        let app = launchStudio()
        let play = app.buttons["prompter.playButton"]
        play.tap()
        XCTAssertTrue(element(app, "prompter.countdown").waitForExistence(timeout: 3))
        try capture(app, "studio_countdown")
        let playing = NSPredicate(format: "label == 'Pause'")
        expectation(for: playing, evaluatedWith: play)
        waitForExpectations(timeout: 10)
        play.tap()
        XCTAssertEqual(play.label, "Play")
    }
}
