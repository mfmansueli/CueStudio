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

    func testVoiceFollowCanBeTurnedOn() {
        let app = CueApp.launch(seeded: true)
        let studio = app.buttons["hero.studioButton"]
        XCTAssertTrue(studio.waitForExistence(timeout: 15))
        studio.tap()

        app.buttons["prompter.displayButton"].tap()
        let voice = app.buttons["Voice follow"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        voice.tap()
        allowMicrophoneIfAsked()
        XCTAssertTrue(app.staticTexts["display.voiceFollowNote"].waitForExistence(timeout: 5))

        app.buttons["display.doneButton"].tap()
        let play = app.buttons["prompter.playButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertEqual(play.label, "Pause")
        app.buttons["prompter.closeButton"].tap()
        XCTAssertTrue(studio.waitForExistence(timeout: 5))
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

    // MARK: - Helpers

    /// Voice follow listens to the microphone; the Simulator asks once.
    private func allowMicrophoneIfAsked() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 3) {
            allow.tap()
        }
    }
}
