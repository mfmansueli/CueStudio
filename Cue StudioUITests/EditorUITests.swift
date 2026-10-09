//
//  EditorUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The editor (Quick edit) from a take's review, on a small real video: the toolbar by context, a
/// panel's ✓, full screen, splitting and deleting a clip, undo and Done.
@MainActor
final class EditorUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheEditorOpensWithTheMainTools() {
        let app = EditorApp.open()
        XCTAssertTrue(app.buttons["edit.doneButton"].exists)
        XCTAssertTrue(app.buttons["edit.backButton"].exists)
        XCTAssertFalse(app.buttons["edit.exportButton"].exists)
        XCTAssertTrue(app.buttons["edit.playButton"].exists)
        // v29 · 7.2: CapCut's order, Smart before Cover; Adjust, Crop, Background and Overlay are Edit's clip tools.
        for tool in ["edit", "audio", "text", "captions", "filters", "smart", "cover"] {
            XCTAssertTrue(app.buttons["edit.toolbar.\(tool)"].exists, tool)
        }
        for tool in ["adjust", "crop", "background", "media"] {
            XCTAssertFalse(app.buttons["edit.toolbar.\(tool)"].exists, tool)
        }
        XCTAssertFalse(app.buttons["edit.toolbar.back"].exists)
    }

    func testEditShowsTheClipsToolsAndBackReturns() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "edit")
        XCTAssertTrue(app.buttons["edit.toolbar.split"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit.toolbar.speed"].exists)
        XCTAssertTrue(app.buttons["edit.toolbar.zoom"].exists)
        EditorApp.tapTool(app, "back")
        XCTAssertTrue(app.buttons["edit.toolbar.smart"].waitForExistence(timeout: 5))
    }

    func testAPanelReplacesTheToolbarUntilItsCheckmark() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "adjust")
        let apply = app.buttons["edit.panel.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["edit.toolbar.adjust"].exists)
        apply.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.adjust"].waitForExistence(timeout: 5))
    }

    func testAdjustPicksASettingAndMovesItsRuler() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "adjust")
        let warmth = app.buttons["edit.adjust.warmth"]
        XCTAssertTrue(warmth.waitForExistence(timeout: 5))
        warmth.tap()
        XCTAssertTrue(warmth.isSelected)
        // The ruler is one adjustable element (not a system slider): a touch sets the value under it.
        let ruler = app.descendants(matching: .any)["edit.adjust.ruler"]
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        XCTAssertEqual(ruler.label, "Warmth")
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        XCTAssertNotEqual(warmth.value as? String, "0")
        // Off zero: the dial says so and its own Reset shows.
        XCTAssertTrue(app.buttons["edit.adjust.resetOne"].waitForExistence(timeout: 5))
        app.buttons["edit.adjust.resetOne"].tap()
        XCTAssertFalse(app.buttons["edit.adjust.resetOne"].exists)
    }

    /// Skin Smoothing is the last chip of Adjust, off at 0, with a ruler and a Reset of its own like the other settings.
    func testSkinSmoothingIsAnAdjustSettingWithItsOwnRulerAndReset() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "adjust")
        let chip = app.buttons["edit.adjust.skinSmoothing"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertEqual(chip.label, "Skin Smoothing")
        XCTAssertEqual(chip.value as? String, "0")
        // The row of settings scrolls sideways: the last chip comes into reach.
        // Drag the row of chips from its right to its left, level with the first chip, until the last one is on screen.
        let window = app.windows.firstMatch.frame
        let level = app.buttons["edit.adjust.exposure"].frame.midY / window.height
        for _ in 0..<5 where !window.contains(chip.frame) {
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: level))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: level)))
        }
        chip.tap()
        XCTAssertTrue(chip.isSelected)
        let ruler = app.descendants(matching: .any)["edit.adjust.ruler"]
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        XCTAssertEqual(ruler.label, "Skin Smoothing")
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertNotEqual(chip.value as? String, "0", "the ruler sets the smoothing")
        XCTAssertTrue(app.buttons["edit.adjust.resetOne"].waitForExistence(timeout: 5))
        app.buttons["edit.adjust.resetOne"].tap()
        XCTAssertEqual(chip.value as? String, "0")
        XCTAssertFalse(app.buttons["edit.adjust.resetOne"].exists)
    }

    /// Auto measures the real frames of the clip: it ends with a correction to dial down, or says the picture is
    /// already balanced; either way the picture is never left half-done.
    func testAutoMeasuresTheClipAndCompareShowsTheOriginal() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "adjust")
        let auto = app.buttons["edit.adjust.auto"]
        XCTAssertTrue(auto.waitForExistence(timeout: 5))
        auto.tap()
        // Measuring takes a moment; it ends with the intensity ruler, or a note when there's nothing to do.
        let amount = app.descendants(matching: .any)["edit.adjust.autoAmount"]
        var balanced = false
        var failed = false
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline, !amount.exists, !balanced, !failed {
            balanced = EditorApp.toastSays(app, "Already balanced", timeout: 0.5)
            failed = EditorApp.toastSays(app, "Couldn’t measure", timeout: 0.5)
        }
        if amount.exists {
            // Intensity is its own ruler; Compare shows the picture as recorded, and Reset takes Auto away.
            let compare = app.buttons["edit.adjust.compare"]
            XCTAssertTrue(compare.exists)
            // ◐ is held: it shows the original only while pressed, and lets go when the finger lifts.
            compare.press(forDuration: 0.5)
            XCTAssertFalse(compare.isSelected)
            XCTAssertTrue(app.buttons["edit.adjust.resetOne"].waitForExistence(timeout: 5))
            app.buttons["edit.adjust.resetOne"].tap()
            XCTAssertFalse(amount.exists)
        } else {
            XCTAssertTrue(balanced || failed)
        }
        XCTAssertTrue(auto.isEnabled)
    }

    func testFiltersOfferTheCollectionAndStartAtTheirOwnIntensity() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "filters")
        for id in ["original", "natural", "studio", "soft", "cinema", "warmEditorial", "retro", "monoSoft", "monoContrast"] {
            XCTAssertTrue(app.buttons["edit.filter.\(id)"].waitForExistence(timeout: 5), id)
        }
        // The first filters only show while one of them is picked.
        XCTAssertFalse(app.buttons["edit.filter.vivid"].exists)
        let cinema = app.buttons["edit.filter.cinema"]
        cinema.tap()
        XCTAssertTrue(cinema.isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["edit.filter.intensity"].waitForExistence(timeout: 5))
    }

    /// The ruler is the panel's lowest control: it stays above the bottom safe area (the Home
    /// Indicator's strip) and the clearance the panel keeps under its controls, on any iPhone.
    func testAdjustRulerStaysAboveTheBottomEdge() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "adjust")
        let ruler = app.descendants(matching: .any)["edit.adjust.ruler"]
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(ruler.frame.maxY, window.maxY - 20)
        XCTAssertTrue(ruler.isHittable)
    }

    /// Play plays and pause stops. On a device the playhead moves through the take while it plays; the Simulator can't draw the editor's
    /// composition (the item fails with -12784 before it is ready, as `QuickEditPlayerTests` notes), so there only the state is checked.
    func testPlayPlaysAndPauseHoldsThePlayhead() {
        let app = EditorApp.open()
        let play = app.buttons["edit.playButton"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        XCTAssertEqual(play.label, "Play")
        let time = app.staticTexts["edit.timeLabel"]
        let start = time.value as? String ?? time.label
        play.tap()
        XCTAssertEqual(play.label, "Pause")
        #if !targetEnvironment(simulator)
        let moving = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value != %@", start), object: time)
        XCTAssertEqual(XCTWaiter.wait(for: [moving], timeout: 8), .completed, "the playhead didn't move")
        #endif
        play.tap()
        XCTAssertEqual(play.label, "Play")
        let held = time.value as? String
        sleep(1)
        XCTAssertEqual(time.value as? String, held, "pause didn't hold the playhead")
    }

    func testFullScreenShowsOnlyTheVideoAndComesBack() {
        let app = EditorApp.open()
        app.buttons["edit.fullScreenButton"].tap()
        let exit = app.descendants(matching: .any)["edit.exitFullScreen"]
        XCTAssertTrue(exit.waitForExistence(timeout: 5))
        exit.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].waitForExistence(timeout: 5))
    }

    func testSplittingDeletingUndoingAndSavingAClip() {
        let app = EditorApp.open()
        XCTAssertTrue(EditorApp.length(app).hasPrefix("01:02.0"))
        EditorApp.tapTool(app, "edit")
        // At the very start the playhead can't split: a toast says why.
        EditorApp.tapTool(app, "split")
        XCTAssertTrue(app.staticTexts["Move playhead onto the clip"].waitForExistence(timeout: 5))
        EditorApp.tapTool(app, "back")

        EditorApp.scrub(app)
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "split")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Split at'")).firstMatch.waitForExistence(timeout: 5))
        EditorApp.tapTool(app, "delete")
        XCTAssertFalse(EditorApp.length(app).hasPrefix("01:02.0"))
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(EditorApp.length(app).hasPrefix("01:02.0"))
        app.buttons["edit.redoButton"].tap()
        XCTAssertFalse(EditorApp.length(app).hasPrefix("01:02.0"))

        EditorApp.done(app)
        XCTAssertTrue(app.buttons["review.editButton"].waitForExistence(timeout: 5))
    }

    /// The largest text size: the video, the timeline and the tools stay; a panel scrolls.
    func testTheLargestTextKeepsTheVideoAndTheTools() {
        let app = EditorApp.open(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.descendants(matching: .any)["edit.preview"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["edit.timeline"].exists)
        EditorApp.tapTool(app, "adjust")
        let apply = app.buttons["edit.panel.apply"]
        XCTAssertTrue(apply.waitForExistence(timeout: 5))
        XCTAssertTrue(apply.isHittable)
        XCTAssertTrue(app.descendants(matching: .any)["edit.preview"].frame.height >= 150)
        apply.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.adjust"].waitForExistence(timeout: 5))
    }

    /// Done always asks "Is it ready to post?", with four answers; swiping the sheet down goes back.
    func testDoneAsksIfItIsReadyToPost() {
        let app = EditorApp.open()
        app.buttons["edit.doneButton"].tap()
        XCTAssertTrue(app.buttons["edit.done.share"].waitForExistence(timeout: 5))
        for answer in ["download", "ready", "notYet"] {
            XCTAssertTrue(app.buttons["edit.done.\(answer)"].exists, answer)
        }
        // Back to the editor: the sheet swipes down and the tools are still there.
        app.descendants(matching: .any)["edit.doneSheet"].firstMatch.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["edit.done.share"].waitForNonExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].waitForExistence(timeout: 5))
    }

    /// "Not yet, I'll come back" leaves the edit open: the review offers to continue it.
    func testNotYetKeepsTheEditOpenAndTheReviewSaysContinue() {
        let app = EditorApp.open()
        EditorApp.done(app, answer: "notYet")
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        let continues = NSPredicate(format: "label == 'Continue'")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: continues, object: edit)], timeout: 8), .completed, edit.label)
        // And the stage bar says so: the video is in edit.
        XCTAssertTrue(app.descendants(matching: .any)["review.stageBar"].exists)
    }

    /// Back asks nothing and keeps the draft.
    func testBackLeavesWithoutAskingAndKeepsTheDraft() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "edit")
        EditorApp.scrub(app)
        EditorApp.tapTool(app, "split")
        app.buttons["edit.backButton"].tap()
        XCTAssertFalse(app.buttons["edit.done.share"].exists)
        XCTAssertTrue(app.buttons["review.editButton"].waitForExistence(timeout: 5))
    }

    /// Done › "Yes — share": the edited video is made and "Ready to travel" opens over the review (it used to close the app).
    func testSharingRightAfterEditingOpensReadyToTravel() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "edit")
        EditorApp.scrub(app)
        EditorApp.tapTool(app, "split")
        EditorApp.done(app, answer: "share")
        XCTAssertTrue(app.descendants(matching: .any)["ready.sheet"].waitForExistence(timeout: 30), "Ready to travel never opened")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Edited, back in the review: its Share makes the edited video and "Ready to travel" opens.
    func testTheReviewsShareAfterAnEditOpensReadyToTravel() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "edit")
        EditorApp.scrub(app)
        EditorApp.tapTool(app, "split")
        EditorApp.done(app)
        let share = app.buttons["review.shareButton"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ready.sheet"].waitForExistence(timeout: 30), "Ready to travel never opened")
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Timeline

    func testDraggingTheTimelineScrubsThePlayhead() {
        let app = EditorApp.open()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertEqual(time.value as? String, "00:00.0 / 01:02.0")
        EditorApp.scrub(app)
        XCTAssertNotEqual(time.value as? String, "00:00.0 / 01:02.0")
        XCTAssertTrue((time.value as? String)?.hasSuffix("/ 01:02.0") ?? false)
    }

    func testTappingTheVideoTrackPicksTheClipAndEmptySpaceLetsGo() {
        let app = EditorApp.open()
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        EditorApp.mainTrack(app, at: 0.75).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.split"].waitForExistence(timeout: 5))
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.97)).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.smart"].waitForExistence(timeout: 5))
    }

    func testTheClipsLeftHandleTrimsItsStart() {
        let app = EditorApp.open()
        EditorApp.mainTrack(app, at: 0.75).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.split"].waitForExistence(timeout: 5))
        // With the playhead at the start, the clip's left handle sits just left of the middle.
        let handle = EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: -7, dy: 0))
        handle.press(forDuration: 0.2, thenDragTo: handle.withOffset(CGVector(dx: 88, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.3)
        XCTAssertFalse(EditorApp.length(app).hasPrefix("01:02.0"))
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(EditorApp.length(app).hasPrefix("01:02.0"))
    }
}
