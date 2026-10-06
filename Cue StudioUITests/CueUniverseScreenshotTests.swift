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
        element(app, "review.takeLabel").tap()
        app.buttons["Suggest best"].tap()
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
        XCTAssertTrue(element(app, "settings.recording").waitForExistence(timeout: 10))
        capture(app, "settings-1-home")
        var personalize = element(app, "settings.personalize")
        for _ in 0..<4 where !(personalize.exists && personalize.isHittable) { app.swipeUp() }
        personalize = element(app, "settings.personalize")
        XCTAssertTrue(personalize.waitForExistence(timeout: 5))
        personalize.tap()
        XCTAssertTrue(element(app, "settings.appIcon").waitForExistence(timeout: 5))
        capture(app, "settings-2-personalize")
        let sky = element(app, "settings.starrySky")
        XCTAssertEqual(sky.value as? String, "Calm")
        element(app, "settings.appIcon").tap()
        // Default is the one lit; the others open with videos shared.
        XCTAssertTrue(app.buttons["settings.appIcon.standard"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.appIcon.standard"].isSelected)
        app.navigationBars.buttons.firstMatch.tap()
        app.navigationBars.buttons.firstMatch.tap()
        element(app, "settings.prompter").tap()
        XCTAssertTrue(element(app, "settings.followVoice").waitForExistence(timeout: 5))
        capture(app, "settings-3-prompter")
        app.swipeUp()
        capture(app, "settings-4-prompter-more")
    }

    /// Studio has no camera, so the text, the rail and the label show in the simulator.
    func testTheStudioRail() {
        let app = CueApp.launch(seeded: true)
        app.openStudio(titled: "Oat & Co. — sponsored read")
        XCTAssertTrue(element(app, "prompter.sectionRail").waitForExistence(timeout: 10))
        capture(app, "prompter-1-studio-rail")
        app.buttons["prompter.playButton"].tap()
        sleep(3)
        capture(app, "prompter-2-studio-playing")
    }

    /// "Ready to travel", then the networks, a network's step and the send-off.
    func testReadyToTravelAndTheSendOff() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestFakeShareSheet"])
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let share = app.buttons["review.shareButton"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        XCTAssertTrue(element(app, "shareFlow.start").waitForExistence(timeout: 120))
        capture(app, "ready-1-networks")
        app.buttons["shareFlow.start"].tap()
        XCTAssertTrue(element(app, "shareFlow.step").waitForExistence(timeout: 30))
        capture(app, "ready-2-step")
        app.buttons["shareFlow.send"].tap()
        XCTAssertTrue(app.buttons["debug.share.complete"].waitForExistence(timeout: 10))
        app.buttons["debug.share.complete"].tap()
        XCTAssertTrue(element(app, "shareFlow.confirm").waitForExistence(timeout: 10))
        capture(app, "ready-3-posted-question")
        app.buttons["shareFlow.live"].tap()
        XCTAssertTrue(element(app, "sendoff.sheet").waitForExistence(timeout: 20))
        sleep(4)
        capture(app, "sendoff-1-on-its-way")
    }
}
