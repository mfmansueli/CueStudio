//
//  EditorStressDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The editor under a busy creator's hands, with the real animations: full screen in and out, every track out and back, the
/// timeline dragged up and down and the Media bar opened and closed, round after round, and the editor still answers at the end.
/// An iPhone froze doing this (07/11/2026: a watchdog kill with the main thread inside the full-screen preview's first frame).
/// Opt-in: `CUE_DEVICE=… TEST_RUNNER_CUE_STRESS_UI=1 [TEST_RUNNER_CUE_REAL_TAKE=<file in Takes>] scripts/test.sh device-ui EditorStressDeviceUITests`.
@MainActor
final class EditorStressDeviceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_STRESS_UI"] != nil else {
            throw XCTSkip("Opt-in: TEST_RUNNER_CUE_STRESS_UI=1")
        }
    }

    func testFullScreenTracksAndBarsRoundAfterRoundLeaveTheEditorAnswering() {
        // A copy of a real take (`TEST_RUNNER_CUE_REAL_TAKE`) draws real frames, which the full-screen preview holds as it opens.
        let take = ProcessInfo.processInfo.environment["CUE_REAL_TAKE"]
        let app = take.map { EditorApp.open(animations: true, arguments: ["-uiTestRealTake", $0]) } ?? EditorApp.open(demo: true, animations: true)
        // Playing, as a creator checks the edit between moves.
        app.buttons["edit.playButton"].tap()
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        let fullScreen = app.buttons["edit.fullScreenButton"]
        let exit = app.descendants(matching: .any)["edit.exitFullScreen"]
        let rounds = Int(ProcessInfo.processInfo.environment["CUE_STRESS_ROUNDS"] ?? "") ?? 12
        for round in 1...rounds {
            let start = Date()
            XCTAssertTrue(fullScreen.exists(within: 10), "Round \(round): no full-screen button (the editor stopped answering?)")
            fullScreen.tap()
            XCTAssertTrue(exit.exists(within: 10), "Round \(round): full screen didn't open")
            exit.tap()
            XCTAssertTrue(timeline.exists(within: 10), "Round \(round): the timeline didn't come back")
            // Every track out and back by the current track's square, then the same by dragging the timeline.
            let square = timeline.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 20, dy: 92 + 22))
            square.tap()
            square.tap()
            let middle = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.6, dy: 0.5))
            middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: -160)))
            middle.press(forDuration: 0.05, thenDragTo: middle.withOffset(CGVector(dx: 0, dy: 160)))
            // Short quick drags down on the video, let go before full screen (the video springs back into its card), then a
            // whole one into full screen and up out of it: each drag down builds the full-screen preview as it starts.
            // The card's (the full-screen one, under it while out of sight, is the disabled one).
            let preview = app.descendants(matching: .any).matching(NSPredicate(format: "identifier == 'edit.preview' AND enabled == true")).firstMatch
            if preview.exists {
                let top = preview.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
                for _ in 0..<4 {
                    top.press(forDuration: 0.02, thenDragTo: top.withOffset(CGVector(dx: 0, dy: 50)), withVelocity: .fast, thenHoldForDuration: 0)
                }
                top.press(forDuration: 0.02, thenDragTo: top.withOffset(CGVector(dx: 0, dy: 260)), withVelocity: .fast, thenHoldForDuration: 0)
                if exit.exists(within: 3) {
                    let screen = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.6))
                    screen.press(forDuration: 0.02, thenDragTo: screen.withOffset(CGVector(dx: 0, dy: -300)), withVelocity: .fast, thenHoldForDuration: 0)
                }
            }
            EditorApp.tapTool(app, "addMedia")
            let back = app.buttons["edit.toolbar.back"]
            if back.exists(within: 3) { back.tap() }
            print("STRESS round \(round) took \(String(format: "%.1f", Date().timeIntervalSince(start))) s")
        }
        // Still answering: the play button turns to pause and back.
        let play = app.buttons["edit.playButton"]
        XCTAssertTrue(play.exists(within: 10), "The editor stopped answering")
        play.tap()
        play.tap()
        XCTAssertEqual(app.state, .runningForeground)
        EditorApp.capture(app, "stress-end")
    }
}
