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
        app.openStudio(titled: "Oat & Co. — sponsored read")

        let play = app.buttons["prompter.playButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Play")
        play.tap()
        // From the top it counts down first (3 s by default), then plays.
        let playing = NSPredicate(format: "label == 'Pause'")
        expectation(for: playing, evaluatedWith: play)
        waitForExpectations(timeout: 10)
        play.tap()

        app.buttons["prompter.displayButton"].tap()
        let done = app.buttons["display.doneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        done.tap()

        app.buttons["prompter.closeButton"].tap()
        XCTAssertTrue(app.staticTexts["Oat & Co. — sponsored read"].waitForExistence(timeout: 5))
    }

    func testStudioSwitchesToVoiceFollowing() {
        let app = CueApp.launch(seeded: true)
        app.openStudio(titled: "Oat & Co. — sponsored read")

        XCTAssertTrue(element(app, "prompter.speedSlider").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["prompter.backButton"].exists)
        XCTAssertTrue(app.buttons["prompter.forwardButton"].exists)
        app.buttons["prompter.scrollMode.voice"].tap()
        allowMicrophoneIfAsked()
        XCTAssertTrue(element(app, "prompter.voiceIndicator").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "prompter.speedSlider").exists)
        let play = app.buttons["prompter.playButton"]
        play.tap()
        // The Simulator can't run speech recognition: there the text scrolls at the set speed while
        // you talk, and says so, speed included. It never claims to follow the words.
        let status = element(app, "prompter.voiceStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        let honest = NSPredicate(format: "label CONTAINS 'while you talk' AND label CONTAINS '7×'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: honest, evaluatedWith: status)], timeout: 10), .completed)
        XCTAssertNotEqual(status.label, "Follows your words")
        play.tap()
        app.buttons["prompter.closeButton"].tap()
        XCTAssertTrue(app.staticTexts["Oat & Co. — sponsored read"].waitForExistence(timeout: 5))
    }

    func testVoiceFollowingIsOneTapInTheToolbar() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let voice = app.buttons["prompter.scrollMode.voice"]
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        let speed = element(app, "prompter.speedSlider")
        XCTAssertTrue(speed.exists)
        // The natural pace, in words a minute.
        XCTAssertEqual(speed.value as? String, "150 words a minute")
        voice.tap()
        allowMicrophoneIfAsked()
        let indicator = element(app, "prompter.voiceIndicator")
        XCTAssertTrue(indicator.waitForExistence(timeout: 5))
        XCTAssertTrue(voice.isSelected)
        XCTAssertFalse(speed.exists)
        // Getting ready, then (the Simulator can't recognize speech) scrolling while you talk:
        // never "Listening" to the words while paused, and never stuck getting ready.
        let settled = NSPredicate(format: "value == 'Paused'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: settled, evaluatedWith: indicator)], timeout: 10), .completed)

        app.buttons["prompter.scrollMode.steady"].tap()
        XCTAssertFalse(element(app, "prompter.voiceIndicator").waitForExistence(timeout: 2))
        XCTAssertTrue(speed.exists)
        app.buttons["prompter.closeButton"].tap()
        XCTAssertTrue(record.waitForExistence(timeout: 5))
    }

    /// Aa opens the Prompter page of Settings (09 §11) over the recording, with a preview on top.
    func testAaOpensThePrompterPageOverTheRecorder() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        XCTAssertTrue(element(app, "prompter.text").waitForExistence(timeout: 5))
        app.buttons["prompter.displayButton"].tap()
        XCTAssertTrue(app.buttons["display.doneButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "settings.prompterPreview").exists)
        XCTAssertTrue(element(app, "settings.followVoice").exists)
        XCTAssertTrue(element(app, "settings.speed").exists)
        app.buttons["display.doneButton"].tap()
    }

    func testReadingLineMovesFromThePrompterPageAndResetsToRecommended() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let handle = element(app, "prompter.readingLineHandle")
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["prompter.readingLineTip"].exists)
        let lineY = handle.frame.midY
        app.buttons["prompter.displayButton"].tap()
        let position = app.sliders["settings.readingLinePosition"]
        XCTAssertTrue(element(app, "settings.followVoice").waitForExistence(timeout: 5))
        // The list is under the sheet's handle: drag from its lower half, where the rows are.
        for _ in 0..<6 where !(position.exists && position.isHittable) {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            from.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)))
        }
        XCTAssertTrue(position.waitForExistence(timeout: 5))
        position.adjust(toNormalizedSliderPosition: 0.9)
        XCTAssertNotEqual(handle.frame.midY, lineY, accuracy: 1)

        let reset = element(app, "settings.resetReadingLine")
        XCTAssertTrue(reset.waitForExistence(timeout: 5))
        reset.tap()
        // The line glides back to where it is recommended: wait for it to arrive.
        let arrived = NSPredicate { _, _ in abs(handle.frame.midY - lineY) <= 2 }
        expectation(for: arrived, evaluatedWith: nil)
        waitForExpectations(timeout: 4)
        XCTAssertEqual(handle.frame.midY, lineY, accuracy: 2)
        app.buttons["display.doneButton"].tap()
        XCTAssertFalse(app.buttons["prompter.readingLineTip"].exists)
    }

    func testTextWindowResizesFromItsCornerAndResetsOnDoubleTap() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let handle = element(app, "prompter.textWindowResizeHandle")
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        let original = handle.value as? String
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -90, dy: -120)))
        XCTAssertNotEqual(handle.value as? String, original, "dragging the corner changes the window")

        handle.doubleTap()
        XCTAssertEqual(handle.value as? String, original, "a double-tap puts the original size back")

        // Nothing resizes while a sheet is open.
        app.buttons["prompter.displayButton"].tap()
        XCTAssertTrue(app.buttons["display.doneButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(handle.exists)
        app.buttons["display.doneButton"].tap()
    }

    /// Social safe zone, from the Prompter page: the platforms, Custom with its own margins.
    func testCustomSafeZoneFromThePrompterPage() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        XCTAssertTrue(app.buttons["prompter.displayButton"].waitForExistence(timeout: 5))
        app.buttons["prompter.displayButton"].tap()
        let zone = element(app, "settings.socialSafeZone")
        app.scroll(to: zone)
        zone.tap()
        XCTAssertTrue(element(app, "settings.safeZoneToggle").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["settings.safeZone.reels"].exists)
        XCTAssertFalse(element(app, "settings.safeZoneMargin.top").exists)
        let custom = app.buttons["settings.safeZone.custom"]
        custom.tap()
        XCTAssertTrue(custom.isSelected)
        XCTAssertTrue(element(app, "settings.safeZoneMargin.top").waitForExistence(timeout: 2))
    }

    func testPlatformChipOpensCreateFor() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let chip = app.buttons["prompter.aspectButton"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertTrue(chip.label.contains("TikTok"))
        chip.tap()
        let youtube = app.buttons["destination.youtube"]
        XCTAssertTrue(youtube.waitForExistence(timeout: 5))
        youtube.tap()
        // The toast is brief; the chip is the lasting proof the platform changed.
        let youtubeChip = app.buttons.matching(NSPredicate(format: "identifier == 'prompter.aspectButton' AND label CONTAINS 'YouTube'")).firstMatch
        XCTAssertTrue(youtubeChip.waitForExistence(timeout: 5))
        // YouTube's 16:9 · 4K · 24 fps is offered, not applied: the frame stays 9:16 until the creator picks.
        XCTAssertTrue(youtubeChip.label.contains("9:16"))
        let use = app.buttons["prompter.useRecommendedButton"]
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        XCTAssertEqual(use.label, "Use Recommended")
        use.tap()
        let landscape = app.buttons.matching(NSPredicate(format: "identifier == 'prompter.aspectButton' AND label CONTAINS '16:9'")).firstMatch
        XCTAssertTrue(landscape.waitForExistence(timeout: 5))
        app.buttons["prompter.closeButton"].tap()
    }

    func testMicrophonePillPicksTheAudioInput() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        allowMicrophoneIfAsked()

        let pill = app.buttons["prompter.audioInputButton"]
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        XCTAssertTrue(app.staticTexts["Audio Input"].waitForExistence(timeout: 5))

        // Whatever the Simulator offers: picking an input closes the sheet and the pill names it.
        let option = app.buttons.matching(identifier: "audioInput.option").firstMatch
        if option.waitForExistence(timeout: 2) {
            let name = option.label.components(separatedBy: ",").first ?? option.label
            option.tap()
            XCTAssertTrue(app.staticTexts["Audio Input"].waitForNonExistence(timeout: 5))
            XCTAssertEqual(pill.value as? String, name)
        } else {
            app.buttons.matching(NSPredicate(format: "label == 'Close' AND identifier != 'prompter.closeButton'")).firstMatch.tap()
            XCTAssertTrue(app.staticTexts["Audio Input"].waitForNonExistence(timeout: 5))
        }
        XCTAssertTrue(app.buttons["prompter.recordButton"].exists)
        app.buttons["prompter.closeButton"].tap()
    }

    /// The toolbar's "•••" holds what has no room on the bar: Countdown, Remote Control and "This take".
    func testMoreMenuHoldsCountdownRemoteControlAndThisTake() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        let more = app.buttons["prompter.moreButton"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        XCTAssertTrue(app.buttons["prompter.moreRemote"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["prompter.moreThisTake"].exists)
        app.buttons["prompter.moreThisTake"].tap()
        XCTAssertTrue(app.buttons["sheet.closeButton"].waitForExistence(timeout: 5))
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(app.buttons["sheet.closeButton"].waitForNonExistence(timeout: 5))
        app.buttons["prompter.closeButton"].tap()
    }

    /// The v26 toolbar: Voice | Steady with back to the top, play and Aa, the speed slider, the HUD
    /// line with the microphone and the setup, and the capture row.
    func testTheToolbarHasTheV26Controls() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()

        XCTAssertTrue(app.buttons["prompter.scrollMode.voice"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["prompter.scrollMode.voice"].label, "Voice Following")
        XCTAssertTrue(app.buttons["prompter.scrollMode.steady"].exists)
        for id in ["prompter.playButton", "prompter.displayButton", "prompter.audioInputButton", "prompter.setupButton",
                   "prompter.cameraSettingsButton", "prompter.recordButton", "prompter.moreButton", "prompter.lastTakeButton",
        ] {
            XCTAssertTrue(element(app, id).exists, "Missing \(id)")
        }
        // Dragging the thumb along the speed slider changes the speed.
        let speed = element(app, "prompter.speedSlider")
        XCTAssertTrue(speed.exists)
        let before = speed.value as? String
        // The orb sits a little past the middle of the pill at the natural pace.
        let start = speed.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 70, dy: 0)))
        XCTAssertNotEqual(speed.value as? String, before)
        app.buttons["prompter.closeButton"].tap()
    }

    func testSelfieModeSwitchesToStudio() throws {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
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
        let record = app.buttons["row.recordButton"].firstMatch
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
