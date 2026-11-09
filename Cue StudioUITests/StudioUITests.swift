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
        app.openStudio(titled: "Oat & Co. · sponsored read")
        XCTAssertTrue(app.buttons["prompter.playButton"].exists(within: 10))
        return app
    }

    func testStudioHasNoCameraAndNothingToRecord() throws {
        let app = launchStudio()
        XCTAssertTrue(element(app, "prompter.sectionRail").exists(within: 5), "Studio has no camera: the text's rail shows")
        XCTAssertTrue(element(app, "prompter.remoteButton").exists(within: 5), "Studio is the prompter a remote drives")
        XCTAssertFalse(element(app, "prompter.aspectButton").exists, "Studio has no camera frame")
        XCTAssertFalse(app.buttons["prompter.recordButton"].exists)
        XCTAssertFalse(element(app, "prompter.studioPreview").exists)
        XCTAssertFalse(app.buttons["prompter.cameraSettingsButton"].exists)
        XCTAssertFalse(element(app, "prompter.audioInputButton").exists)
        let scrollMode = app.descendants(matching: .any)["prompter.scrollMode"].firstMatch
        XCTAssertTrue(scrollMode.buttons["Voice"].exists && scrollMode.buttons["Steady"].exists)
        XCTAssertTrue(element(app, "prompter.speedSlider").exists)
        XCTAssertTrue(element(app, "studio.timeLeft").exists(within: 5))
        try capture(app, "studio_idle")
    }

    func testTheChipsOpenOneSliderAtATime() throws {
        let app = launchStudio()
        let size = app.buttons["studio.adjust.size"]
        XCTAssertTrue(size.exists)
        XCTAssertFalse(element(app, "studio.slider.size").exists)
        size.tap()
        XCTAssertTrue(element(app, "studio.slider.size").exists(within: 3))
        XCTAssertTrue(size.isSelected)
        // Points, over the range of Settings › Prompter (12 to 56).
        let sizeSlider = app.sliders["studio.slider.size"]
        XCTAssertEqual(sizeSlider.value as? String, "36 pt")
        sizeSlider.adjust(toNormalizedSliderPosition: 0)
        XCTAssertEqual(sizeSlider.value as? String, "12 pt")
        try capture(app, "studio_size")

        app.buttons["studio.adjust.line"].tap()
        XCTAssertTrue(element(app, "studio.slider.line").exists(within: 3))
        XCTAssertFalse(element(app, "studio.slider.size").exists, "one slider at a time")

        app.buttons["studio.adjust.line"].tap()
        let gone = NSPredicate(format: "exists == false")
        XCTAssertTrue(element(app, "studio.slider.line").matches(gone, within: 3))
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

    /// The chevron folds the quick adjustments and the speed into the bar's sheet, leaving the transport, and brings them back.
    func testTheBarFoldsItsAdjustmentsAndOpensThemAgain() throws {
        let app = launchStudio()
        let handle = element(app, "prompter.sheetHandle")
        XCTAssertTrue(handle.exists(within: 5))
        XCTAssertTrue(app.buttons["studio.adjust.size"].isHittable)
        handle.tap()
        sleep(1)
        XCTAssertFalse(app.buttons["studio.adjust.size"].isHittable, "The adjustments stayed out")
        XCTAssertTrue(app.buttons["prompter.playButton"].isHittable, "The transport must stay")
        try capture(app, "studio_bar_folded")
        handle.tap()
        sleep(1)
        XCTAssertTrue(app.buttons["studio.adjust.size"].isHittable, "The adjustments did not come back")
    }

    /// A keyboard, foot pedal or clicker drives the text like the remote: space plays (after the countdown) and pauses.
    func testSpaceOnAKeyboardOrPedalPlaysAndPauses() {
        let app = launchStudio()
        let play = app.buttons["prompter.playButton"]
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(play.matches(NSPredicate(format: "label == 'Pause'"), within: 12), "Space did not start the text")
        app.typeKey(" ", modifierFlags: [])
        XCTAssertTrue(play.matches(NSPredicate(format: "label == 'Play'"), within: 5), "Space did not pause it")
    }

    /// Play from the top waits for the countdown set in Settings, so there is time to get in front of the other camera, then the text runs.
    func testPlayFromTheTopCountsDownThenPlays() throws {
        let app = launchStudio()
        let play = app.buttons["prompter.playButton"]
        play.tap()
        XCTAssertTrue(element(app, "prompter.countdown").exists(within: 3))
        try capture(app, "studio_countdown")
        let playing = NSPredicate(format: "label == 'Pause'")
        XCTAssertTrue(play.matches(playing, within: 10))
        // The first play folds the bar, and the transport moves with it: tap once it has settled.
        XCTAssertTrue(element(app, "prompter.sheetHandle").matches(NSPredicate(format: "value == 'Hidden'"), within: 5))
        sleep(1)
        // Folded, the sheet's tap area once took the play button in (VoiceOver's ring and the tap on Voice | Steady): it keeps its own size.
        XCTAssertLessThan(play.frame.width, 80, "The play button is \(play.frame)")
        play.tap()
        // Under load (two simulators) the label can take a moment to turn.
        XCTAssertTrue(play.matches(NSPredicate(format: "label == 'Play'"), within: 3), play.label)
    }
}
