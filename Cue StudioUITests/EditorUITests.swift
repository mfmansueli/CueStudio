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

        EditorApp.seek(app, to: 0.5)
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
}
