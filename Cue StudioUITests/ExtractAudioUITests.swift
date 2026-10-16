//
//  ExtractAudioUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Extract audio from the clip's tools: the sound goes to a track of its own, picked with its tools (Volume), and one Undo
/// takes it back. Replace clip opens the system's Photos picker, which XCUITest can't drive; its rules are unit tested
/// (`QuickEditReplaceClipTests`).
@MainActor
final class ExtractAudioUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testExtractAudioPutsTheClipsSoundOnItsOwnTrack() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "extractAudio")
        XCTAssertTrue(EditorApp.toastSays(app, "Sound on its own track", timeout: 20), "No toast after Extract audio")
        // The new track is picked: its tools replace the clip's.
        XCTAssertTrue(app.buttons["edit.toolbar.volume"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit.toolbar.replace"].exists, "The music track's tools aren't shown")
        XCTAssertFalse(app.buttons["edit.toolbar.extractAudio"].exists)
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].waitForExistence(timeout: 5), "Undo didn't take the track back")
    }
}
