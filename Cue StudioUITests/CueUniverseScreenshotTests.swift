//
//  CueUniverseScreenshotTests.swift
//  Cue StudioUITests
//

import XCTest

/// v27 screens: Pick your best take, Settings › Personalize and Prompter, the teleprompter's rail, the export's
/// "Ready to travel" and the send-off. They also check that each opens. Pictures are saved when
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` is set.
@MainActor
final class CueUniverseScreenshotTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "v27-\(name).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testPickYourBestTake() {
        let app = CueApp.launch(seeded: true)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        app.buttons["review.suggestBestButton"].tap()
        XCTAssertTrue(element(app, "pick.sheet").waitForExistence(timeout: 5))
        capture(app, "pick-1-scanning")
        XCTAssertTrue(element(app, "pick.bestBadge").waitForExistence(timeout: 5))
        sleep(3)
        capture(app, "pick-2-picked")
        XCTAssertTrue(app.buttons["pick.recordAgain"].exists && app.buttons["pick.use"].exists)
    }

    func testPersonalizeAndPrompterSettings() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestSky", "calm"])
        app.cueTabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.buttons["settings.recordingTile"].waitForExistence(timeout: 10))
        capture(app, "settings-1-home")
        var personalize = app.buttons["settings.personalizeButton"]
        for _ in 0..<4 where !(personalize.exists && personalize.isHittable) { app.swipeUp() }
        personalize = app.buttons["settings.personalizeButton"]
        XCTAssertTrue(personalize.waitForExistence(timeout: 5))
        personalize.tap()
        XCTAssertTrue(app.buttons["personalize.icon.aurora"].waitForExistence(timeout: 5))
        capture(app, "settings-2-personalize")
        // Aurora is locked until a video is shared; Default is the one lit.
        XCTAssertTrue(app.buttons["personalize.icon.standard"].isSelected)
        let sky = element(app, "personalize.sky")
        XCTAssertEqual(sky.value as? String, "Soft")
        app.navigationBars.buttons.firstMatch.tap()
        app.buttons["settings.prompterTile"].tap()
        XCTAssertTrue(element(app, "creatorSetup.speed").waitForExistence(timeout: 5))
        capture(app, "settings-3-prompter")
        app.swipeUp()
        capture(app, "settings-4-prompter-more")
    }

    /// Studio has no camera, so the text, the rail and the label show in the simulator.
    func testTheStudioRail() {
        let app = CueApp.launch(seeded: true)
        let studio = app.buttons["row.studioButton"].firstMatch
        XCTAssertTrue(studio.waitForExistence(timeout: 15))
        studio.tap()
        XCTAssertTrue(element(app, "prompter.sectionRail").waitForExistence(timeout: 10))
        capture(app, "prompter-1-studio-rail")
        app.buttons["prompter.playButton"].tap()
        sleep(3)
        capture(app, "prompter-2-studio-playing")
    }

    /// Save the video, then "Ready to travel" and the send-off.
    func testReadyToTravelAndTheSendOff() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestAppsInstalled"])
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let share = app.buttons["review.shareButton"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        let save = app.buttons["share.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5))
        save.tap()
        XCTAssertTrue(element(app, "ready.sheet").waitForExistence(timeout: 120))
        capture(app, "ready-1-to-travel")
        app.buttons["ready.shareButton"].tap()
        XCTAssertTrue(element(app, "sendoff.sheet").waitForExistence(timeout: 20))
        sleep(4)
        capture(app, "sendoff-1-on-its-way")
    }
}
