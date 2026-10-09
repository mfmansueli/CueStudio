//
//  ScreenCaptureUITests.swift
//  Cue StudioUITests
//

import notify
import XCTest

/// The video previews while the screen is recorded or mirrored. The Simulator's own recording never marks the scene as captured,
/// so the app starts with `-uiTestSceneCapture on|off` and the test starts and stops "capture" while it runs, the way Control
/// Center's Screen Recording would (`SimulatedSceneCapture`, Darwin notifications). What a real capture looks like on an iPhone
/// is on the device checklist (`DESIGN_PROJECT.md` §26).
@MainActor
final class ScreenCaptureUITests: XCTestCase {
    private static let message = "Stop screen recording or mirroring to view this preview."

    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func capture(_ isOn: Bool) {
        notify_post(isOn ? "studio.cue.uitest.sceneCapture.on" : "studio.cue.uitest.sceneCapture.off")
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func shield(_ app: XCUIApplication) -> XCUIElement {
        element(app, "captureShield")
    }

    private func launch(captured: Bool, arguments: [String] = []) -> XCUIApplication {
        CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestSceneCapture", captured ? "on" : "off"] + arguments)
    }

    /// The review of a "3 morning habits" take (a small real video).
    private func openReview(_ app: XCUIApplication) {
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["review.editButton"].waitForExistence(timeout: 5))
    }

    /// The scrubber's "0:04 of 0:21": where the take is.
    private func reviewPosition(_ app: XCUIApplication) -> String {
        element(app, "review.scrubber").value as? String ?? ""
    }

    // MARK: - Take review

    func testCaptureDuringPlaybackHidesTheReviewAndItsEndLeavesItPausedWhereItWas() {
        let app = launch(captured: false)
        openReview(app)
        XCTAssertFalse(shield(app).exists)
        let play = app.buttons["Play"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(play.waitForNonExistence(timeout: 5), "the take plays")
        sleep(2)

        capture(true)
        XCTAssertTrue(shield(app).waitForExistence(timeout: 5))
        XCTAssertTrue(shield(app).label.contains(Self.message))
        XCTAssertFalse(play.exists, "no play button over the shield")
        let held = reviewPosition(app)
        sleep(2)
        XCTAssertEqual(reviewPosition(app), held, "paused while the screen is captured")
        // A tap on the shield asks a held player to play: nothing happens.
        shield(app).tap()
        sleep(1)
        XCTAssertEqual(reviewPosition(app), held)
        // Everything else still works.
        XCTAssertTrue(app.buttons["review.editButton"].isHittable)
        XCTAssertTrue(app.buttons["review.shareButton"].isHittable)

        capture(false)
        XCTAssertTrue(shield(app).waitForNonExistence(timeout: 5))
        XCTAssertTrue(play.waitForExistence(timeout: 5), "paused, never resumed on its own")
        sleep(2)
        XCTAssertEqual(reviewPosition(app), held, "back where it was")
        play.tap()
        XCTAssertTrue(play.waitForNonExistence(timeout: 5), "the creator plays it again")
    }

    func testCaptureBeforeLaunchHidesTheReviewFromItsFirstFrame() {
        let app = launch(captured: true)
        openReview(app)
        XCTAssertTrue(shield(app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Play"].exists)
        let start = reviewPosition(app)
        shield(app).tap()
        sleep(2)
        XCTAssertEqual(reviewPosition(app), start, "nothing plays")
    }

    // MARK: - Quick edit

    func testTheEditorAndItsFullScreenHideWhileCapturedAndNothingPlays() {
        let app = EditorApp.open(arguments: ["-uiTestSceneCapture", "on"])
        let preview = element(app, "edit.preview")
        XCTAssertTrue(preview.waitForExistence(timeout: 10))
        XCTAssertTrue(shield(app).waitForExistence(timeout: 5))
        let time = app.staticTexts["edit.timeLabel"]
        let start = time.value as? String ?? time.label
        app.buttons["edit.playButton"].tap()
        sleep(2)
        XCTAssertEqual(time.value as? String ?? time.label, start, "the play button can't start a captured preview")
        XCTAssertEqual(app.buttons["edit.playButton"].label, "Play", "the play button can't start a captured preview")

        app.buttons["edit.fullScreenButton"].tap()
        XCTAssertTrue(element(app, "edit.exitFullScreen").waitForExistence(timeout: 5))
        XCTAssertTrue((preview.value as? String ?? "").contains(Self.message), "full screen says why it is hidden")
        // The middle of the screen is the full-screen preview: a tap there plays or pauses.
        app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(1)
        // Outside the video, under it: a 9:16 take fills the width, so the middle of "exit" is the video itself. The editor's own preview stays
        // under the full-screen one: the full-screen one is the taller.
        let previews = app.descendants(matching: .any).matching(identifier: "edit.preview").allElementsBoundByIndex
        let fullScreen = previews.max { $0.frame.height < $1.frame.height } ?? preview
        let below = (fullScreen.frame.maxY + app.windows.firstMatch.frame.maxY) / 2
        app.windows.firstMatch.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: app.windows.firstMatch.frame.midX, dy: below)).tap()
        XCTAssertTrue(element(app, "edit.exitFullScreen").waitForNonExistence(timeout: 5), "out of full screen")
        XCTAssertEqual(time.value as? String ?? time.label, start, "a tap on the full-screen preview plays nothing")

        capture(false)
        XCTAssertTrue(shield(app).waitForNonExistence(timeout: 5))
        sleep(1)
        XCTAssertEqual(time.value as? String ?? time.label, start, "capture ending doesn't play")
        XCTAssertEqual(app.buttons["edit.playButton"].label, "Play", "capture ending doesn't play")
        // Once capture ends the creator plays it again: play is no longer refused. The playhead only moves on a device (the Simulator
        // can't draw the editor's composition: `EditorUITests.testPlayPlaysAndPauseHoldsThePlayhead`).
        app.buttons["edit.playButton"].tap()
        XCTAssertEqual(app.buttons["edit.playButton"].label, "Pause")
        #if !targetEnvironment(simulator)
        let playing = expectation(for: NSPredicate(format: "value != %@", start), evaluatedWith: time)
        wait(for: [playing], timeout: 5)
        #endif
    }

    // MARK: - Recorder

    /// Cue's own recording isn't the screen's: capture starting mid-take hides the camera, and the take records on and is kept,
    /// as long as it was held.
    func testCaptureDuringATakeHidesTheCameraAndTheTakeRecordsOn() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDemoCamera", "-uiTestSceneCapture", "off"])
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        let recordButton = app.buttons["prompter.recordButton"]
        XCTAssertTrue(recordButton.waitForExistence(timeout: 10))
        recordButton.tap()
        let badge = element(app, "prompter.recordingBadge")
        XCTAssertTrue(badge.waitForExistence(timeout: 12))
        sleep(1)

        capture(true)
        sleep(4)
        XCTAssertTrue(badge.exists, "still recording")
        XCTAssertTrue(element(app, "prompter.text").exists, "the script stays readable")

        recordButton.tap()
        XCTAssertTrue(app.buttons["review.shareButton"].waitForExistence(timeout: 20), "the take was kept")
        XCTAssertTrue(shield(app).waitForExistence(timeout: 5), "and its review is hidden too")
        // "0:00 of 0:05": the take is as long as it was held, capture included.
        let length = reviewPosition(app).components(separatedBy: " of ").last ?? ""
        let seconds = length.split(separator: ":").last.flatMap { Int($0) } ?? 0
        XCTAssertGreaterThanOrEqual(seconds, 5, "length \(length)")
        capture(false)
        XCTAssertTrue(shield(app).waitForNonExistence(timeout: 5))
    }
}
