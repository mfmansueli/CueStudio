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
        for tool in ["edit", "audio", "text", "captions", "filters", "adjust", "crop", "background", "media", "smart"] {
            XCTAssertTrue(app.buttons["edit.toolbar.\(tool)"].exists, tool)
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
