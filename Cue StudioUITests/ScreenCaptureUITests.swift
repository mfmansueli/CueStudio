//
//  ScreenCaptureUITests.swift
//  Cue StudioUITests
//

import notify
import XCTest

/// The video previews while the screen is recorded or mirrored: on the free plan they carry Cue's mark and keep playing; on Pro
/// nothing changes (decision of 23/10/2026). The Simulator's own recording never marks the scene as captured,
/// so the app starts with `-uiTestSceneCapture on|off` and the test starts and stops "capture" while it runs, the way Control
/// Center's Screen Recording would (`SimulatedSceneCapture`, Darwin notifications). What a real capture looks like on an iPhone
/// is on the device checklist (`DESIGN_PROJECT.md` §26).
@MainActor
final class ScreenCaptureUITests: XCTestCase {
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

    private func watermark(_ app: XCUIApplication) -> XCUIElement {
        element(app, "captureWatermark")
    }

    private func launch(captured: Bool, arguments: [String] = []) -> XCUIApplication {
        CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestSceneCapture", captured ? "on" : "off"] + arguments)
    }

    /// The review of a "3 morning habits" take (a small real video).
    private func openReview(_ app: XCUIApplication) {
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.exists(within: 5))
        row.tap()
        XCTAssertTrue(app.buttons["review.editButton"].exists(within: 5))
    }

    /// The scrubber's "0:04 of 0:21": where the take is.
    private func reviewPosition(_ app: XCUIApplication) -> String {
        element(app, "review.scrubber").value as? String ?? ""
    }

    // MARK: - Take review

    func testOnTheFreePlanCaptureSignsTheReviewAndItKeepsPlaying() {
        let app = launch(captured: false)
        openReview(app)
        XCTAssertFalse(watermark(app).exists)
        let play = app.buttons["Play"]
        XCTAssertTrue(play.exists(within: 5))
        play.tap()
        XCTAssertTrue(play.isGone(within: 5), "the take plays")

        capture(true)
        XCTAssertTrue(watermark(app).exists(within: 5))
        let during = reviewPosition(app)
        sleep(2)
        XCTAssertNotEqual(reviewPosition(app), during, "it keeps playing under the mark")
        XCTAssertTrue(app.buttons["review.editButton"].isHittable)
        XCTAssertTrue(app.buttons["review.shareButton"].isHittable)

        capture(false)
        XCTAssertTrue(watermark(app).isGone(within: 5))
    }

    func testOnProCaptureChangesNothing() {
        let app = launch(captured: true, arguments: ["-uiTestPro"])
        openReview(app)
        let play = app.buttons["Play"]
        XCTAssertTrue(play.exists(within: 5))
        XCTAssertFalse(watermark(app).exists)
        play.tap()
        XCTAssertTrue(play.isGone(within: 5), "the take plays")
        sleep(1)
        XCTAssertFalse(watermark(app).exists)
    }

    // MARK: - Quick edit

    func testOnTheFreePlanTheEditorAndItsFullScreenAreSignedAndPlay() {
        let app = EditorApp.open(arguments: ["-uiTestSceneCapture", "on"])
        XCTAssertTrue(element(app, "edit.preview").exists(within: 10))
        XCTAssertTrue(watermark(app).exists(within: 5))
        app.buttons["edit.playButton"].tap()
        XCTAssertEqual(app.buttons["edit.playButton"].label, "Pause", "a captured preview plays")
        app.buttons["edit.playButton"].tap()

        app.buttons["edit.fullScreenButton"].tap()
        XCTAssertTrue(element(app, "edit.exitFullScreen").exists(within: 5))
        XCTAssertTrue(watermark(app).exists, "full screen is signed too")

        capture(false)
        XCTAssertTrue(watermark(app).isGone(within: 5))
    }

    // MARK: - Recorder

    /// Cue's own recording isn't the screen's: capture starting mid-take signs the camera on the free plan, and the take records
    /// on and is kept, as long as it was held.
    func testCaptureDuringATakeSignsTheCameraAndTheTakeRecordsOn() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDemoCamera", "-uiTestSceneCapture", "off"])
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.exists(within: 15))
        record.tap()
        let recordButton = app.buttons["prompter.recordButton"]
        XCTAssertTrue(recordButton.exists(within: 10))
        recordButton.tap()
        let badge = element(app, "prompter.recordingBadge")
        XCTAssertTrue(badge.exists(within: 12))
        sleep(1)

        capture(true)
        XCTAssertTrue(watermark(app).exists(within: 5))
        sleep(3)
        XCTAssertTrue(badge.exists, "still recording")
        XCTAssertTrue(element(app, "prompter.text").exists, "the script stays readable")

        recordButton.tap()
        // A TikTok take under 1:00 asks first ("50s short of 1:00").
        let stopAnyway = app.buttons["prompter.stopAnywayButton"]
        if stopAnyway.exists(within: 3) { stopAnyway.tap() }
        XCTAssertTrue(app.buttons["review.shareButton"].exists(within: 20), "the take was kept")
        XCTAssertTrue(watermark(app).exists(within: 5), "and its review is signed too")
        // "0:00 of 0:05": the take is as long as it was held, capture included.
        let length = reviewPosition(app).components(separatedBy: " of ").last ?? ""
        let seconds = length.split(separator: ":").last.flatMap { Int($0) } ?? 0
        XCTAssertGreaterThanOrEqual(seconds, 5, "length \(length)")
        capture(false)
        XCTAssertTrue(watermark(app).isGone(within: 5))
    }
}
