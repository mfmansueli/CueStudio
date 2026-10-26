//
//  RealFaceBlurUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Blur area on one of the creator's own recordings, finger on the glass, on their iPhone: a copy of the take opened in memory
/// (`-uiTestRealTake`, the take itself never changes), Blur area from the main toolbar, the faces found, a tap on the face, its
/// tracking, the area checked along the video, the three styles, ◐, the Blur area track on the timeline, and Done. Every step
/// is photographed (kept in the result bundle) and how long tracking took is attached.
///
/// Opt-in: `TEST_RUNNER_CUE_REAL_TAKE=<file name in Takes> CUE_DEVICE="<iPhone>" scripts/test.sh device-ui RealFaceBlurUITests`
/// (Settings › Developer › Enable UI Automation on), or on the Simulator with a path on the Mac to the recording, its
/// `.cuemotion` next to it (`scripts/test.sh only "Cue StudioUITests/RealFaceBlurUITests"`).
final class RealFaceBlurUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_REAL_TAKE"] != nil else {
            throw XCTSkip("Set TEST_RUNNER_CUE_REAL_TAKE to a take's file name on the iPhone, or a path on the Mac")
        }
    }

    @MainActor
    func testAFaceIsHiddenAndTrackedOnARealTake() throws {
        let name = ProcessInfo.processInfo.environment["CUE_REAL_TAKE"] ?? ""
        let app = EditorApp.open(arguments: ["-uiTestRealTake", name])
        shot(app, "1-editor")

        EditorApp.tapTool(app, "blurArea")
        let face = app.buttons["edit.blur.face.0"]
        XCTAssertTrue(face.exists(within: 15), "No face offered on the creator's own video")
        shot(app, "2-faces")
        let started = Date()
        face.tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.blur.status"].exists(within: 5), "No area's panel")
        let progress = app.descendants(matching: .any)["edit.blur.progress"]
        let deadline = Date().addingTimeInterval(120)
        while progress.exists, Date() < deadline { Thread.sleep(forTimeInterval: 0.2) }
        let tracking = Date().timeIntervalSince(started)
        XCTAssertFalse(progress.exists, "Tracking never finished")
        add(XCTAttachment(string: String(format: "Tracking took %.1f s", tracking)))
        shot(app, "3-tracked")
        let state = app.descendants(matching: .any)["edit.blur.state"]
        add(XCTAttachment(string: "State: \(state.label)"))

        // Along the video, paused at a few moments: the area on the face.
        for (index, points) in [200, 300, 300].enumerated() {
            EditorApp.scrub(app, points: CGFloat(points))
            shot(app, "4-along-\(index)")
        }
        for style in ["blur", "solid", "pixelate"] {
            app.buttons["edit.blur.style.\(style)"].tap()
            shot(app, "5-style-\(style)")
        }
        let compare = app.buttons["edit.compare.blur"]
        if compare.exists {
            compare.tap()
            shot(app, "6-compare")
            compare.tap()
        }
        app.buttons["edit.panel.apply"].tap()
        shot(app, "7-timeline")
        let done = app.buttons["edit.doneButton"].exists ? app.buttons["edit.doneButton"] : app.buttons["Done"]
        if done.exists {
            done.tap()
            shot(app, "8-done")
        }
    }

    @MainActor
    private func shot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
