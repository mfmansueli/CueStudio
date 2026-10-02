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
        XCTAssertTrue(app.buttons["edit.exportButton"].exists)
        XCTAssertTrue(app.buttons["edit.playButton"].exists)
        for tool in ["edit", "text", "captions", "audio", "pauses", "media", "adjust"] {
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
        XCTAssertTrue(app.buttons["edit.toolbar.pauses"].waitForExistence(timeout: 5))
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
        let ruler = app.sliders["edit.adjust.ruler"]
        XCTAssertTrue(ruler.waitForExistence(timeout: 5))
        ruler.adjust(toNormalizedSliderPosition: 0.75)
        // Off zero: the dial says so and its own Reset shows.
        XCTAssertTrue(app.buttons["edit.adjust.resetOne"].waitForExistence(timeout: 5))
        app.buttons["edit.adjust.resetOne"].tap()
        XCTAssertFalse(app.buttons["edit.adjust.resetOne"].exists)
    }

    /// The ruler is the panel's lowest control: it stays above the bottom safe area (the Home
    /// Indicator's strip) and the clearance the panel keeps under its controls, on any iPhone.
    func testAdjustRulerStaysAboveTheBottomEdge() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "adjust")
        let ruler = app.sliders["edit.adjust.ruler"]
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
        let status = app.staticTexts["edit.durationChange"]
        XCTAssertTrue(status.label.hasPrefix("01:02.0"))
        EditorApp.tapTool(app, "edit")
        // At the very start the playhead can't split: a toast says why.
        EditorApp.tapTool(app, "split")
        XCTAssertTrue(app.staticTexts["Move the playhead inside the clip"].waitForExistence(timeout: 5))
        EditorApp.tapTool(app, "back")

        EditorApp.scrub(app)
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "split")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Split at'")).firstMatch.waitForExistence(timeout: 5))
        EditorApp.tapTool(app, "delete")
        XCTAssertFalse(status.label.hasPrefix("01:02.0"))
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(status.label.hasPrefix("01:02.0"))
        app.buttons["edit.redoButton"].tap()
        XCTAssertFalse(status.label.hasPrefix("01:02.0"))

        app.buttons["edit.doneButton"].tap()
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

    /// Export: the choices never go above the recording (the sample is 1080p at 30 fps).
    func testExportOffersWhatTheRecordingAllows() {
        let app = EditorApp.open()
        app.buttons["edit.exportButton"].tap()
        let start = app.buttons["edit.export.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit.export.resolution.hd1080"].isSelected)
        XCTAssertFalse(app.buttons["edit.export.resolution.uhd4K"].isEnabled)
        XCTAssertFalse(app.buttons["edit.export.frameRate.60"].isEnabled)
        app.buttons["edit.export.resolution.hd720"].tap()
        XCTAssertTrue(app.buttons["edit.export.resolution.hd720"].isSelected)
        app.buttons["edit.export.close"].tap()
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.buttons["edit.toolbar.pauses"].waitForExistence(timeout: 5))
    }

    func testTheClipsLeftHandleTrimsItsStart() {
        let app = EditorApp.open()
        let status = app.staticTexts["edit.durationChange"]
        EditorApp.mainTrack(app, at: 0.75).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.split"].waitForExistence(timeout: 5))
        // With the playhead at the start, the clip's left handle sits just left of the middle.
        let handle = EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: -7, dy: 0))
        handle.press(forDuration: 0.2, thenDragTo: handle.withOffset(CGVector(dx: 88, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.3)
        XCTAssertFalse(status.label.hasPrefix("01:02.0"))
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(status.label.hasPrefix("01:02.0"))
    }
}
