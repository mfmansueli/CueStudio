//
//  PrompterUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Opening the prompter in Studio and Selfie mode.
@MainActor
final class PrompterUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testStudioModePlaysAndOpensDisplaySettings() {
        let app = CueApp.launch(seeded: true)
        let studio = app.buttons["hero.studioButton"]
        XCTAssertTrue(studio.waitForExistence(timeout: 15))
        studio.tap()

        let play = app.buttons["prompter.playButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Play")
        play.tap()
        XCTAssertEqual(play.label, "Pause")
        play.tap()

        app.buttons["prompter.displayButton"].tap()
        let done = app.buttons["display.doneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        app.buttons["prompter.closeButton"].tap()
        XCTAssertTrue(studio.waitForExistence(timeout: 5))
    }

    func testStudioSwitchesToVoiceFollowing() {
        let app = CueApp.launch(seeded: true)
        let studio = app.buttons["hero.studioButton"]
        XCTAssertTrue(studio.waitForExistence(timeout: 15))
        studio.tap()

        XCTAssertTrue(app.sliders["Speed"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["prompter.backButton"].exists)
        XCTAssertTrue(app.buttons["prompter.forwardButton"].exists)
        app.buttons["prompter.scrollMode.voice"].tap()
        allowMicrophoneIfAsked()
        XCTAssertTrue(element(app, "prompter.voiceIndicator").waitForExistence(timeout: 5))
        XCTAssertFalse(app.sliders["Speed"].exists)
        let play = app.buttons["prompter.playButton"]
        play.tap()
        XCTAssertTrue(app.staticTexts["Speed follows your voice"].waitForExistence(timeout: 5))
        play.tap()
        app.buttons["prompter.closeButton"].tap()
        XCTAssertTrue(studio.waitForExistence(timeout: 5))
    }

    func testVoiceFollowingIsOneTapInTheToolbar() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["hero.recordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let voice = app.buttons["prompter.scrollMode.voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        voice.tap()
        allowMicrophoneIfAsked()
        XCTAssertTrue(element(app, "prompter.voiceIndicator").waitForExistence(timeout: 5))
        XCTAssertTrue(voice.isSelected)

        app.buttons["prompter.scrollMode.steady"].tap()
        XCTAssertFalse(element(app, "prompter.voiceIndicator").waitForExistence(timeout: 2))
        app.buttons["prompter.closeButton"].tap()
        XCTAssertTrue(record.waitForExistence(timeout: 5))
    }

    func testDisplaySettingsStayBelowTheScriptWithAdvancedTucked() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["hero.recordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let script = element(app, "prompter.text")
        XCTAssertTrue(script.waitForExistence(timeout: 5))
        app.buttons["prompter.displayButton"].tap()
        let done = app.buttons["display.doneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(done.frame.minY, script.frame.maxY)
        XCTAssertTrue(element(app, "display.aiCoachToggle").exists)
        XCTAssertTrue(element(app, "display.readingWidth").exists)
        XCTAssertFalse(app.staticTexts["Line spacing"].exists)
        app.buttons["display.advancedButton"].tap()
        XCTAssertTrue(app.staticTexts["Line spacing"].waitForExistence(timeout: 5))
        done.tap()
    }

    func testPlatformChipOpensCreateFor() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["hero.recordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let chip = app.buttons["prompter.aspectButton"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertTrue(chip.label.contains("TikTok"))
        chip.tap()
        let youtube = app.buttons["destination.youtube"]
        XCTAssertTrue(youtube.waitForExistence(timeout: 5))
        youtube.tap()
        // The toast is brief; the chip is the lasting proof the preset changed.
        let youtubeChip = app.buttons.matching(NSPredicate(format: "identifier == 'prompter.aspectButton' AND label CONTAINS 'YouTube'")).firstMatch
        XCTAssertTrue(youtubeChip.waitForExistence(timeout: 5))
        app.buttons["prompter.closeButton"].tap()
    }

    func testSelfieModeSwitchesToStudio() throws {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["hero.recordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        // The Simulator has no camera, so Cue explains instead of showing a feed.
        if !app.descendants(matching: .any)["camera.unavailableMessage"].waitForExistence(timeout: 5) {
            throw XCTSkip("A camera is available; this check is for devices without one.")
        }
        XCTAssertTrue(app.buttons["prompter.recordButton"].exists)
        app.buttons["prompter.mode.studio"].tap()
        XCTAssertTrue(app.buttons["prompter.playButton"].waitForExistence(timeout: 5))
        app.buttons["prompter.closeButton"].tap()
    }

    func testCameraSettingsStopBelowTheScript() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["hero.recordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let script = app.descendants(matching: .any)["prompter.text"]
        XCTAssertTrue(script.waitForExistence(timeout: 5))
        let scriptBottom = script.frame.maxY

        app.buttons["prompter.cameraSettingsButton"].tap()
        let done = app.buttons["camera.doneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertGreaterThan(done.frame.minY, scriptBottom)

        // Pulling the sheet up doesn't let it grow over the script.
        let header = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: done.frame.minX - 40, dy: done.frame.midY))
        header.press(forDuration: 0.1, thenDragTo: header.withOffset(CGVector(dx: 0, dy: -400)))
        XCTAssertGreaterThan(done.frame.minY, scriptBottom)

        done.tap()
        XCTAssertTrue(app.buttons["prompter.recordButton"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// Voice follow listens to the microphone; the Simulator asks once.
    private func allowMicrophoneIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }
    }
}
