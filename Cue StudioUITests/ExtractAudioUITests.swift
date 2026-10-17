//
//  ExtractAudioUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Extract audio from the clip's tools. The UI tests' sample takes are silent, so here the editor says so and changes nothing
/// (no dead end, no empty track); the sound coming out on its own track, muting the clip, is unit tested
/// (`QuickEditExtractAudioTests`) and measured on real files (`SoundExtractorTests`). Replace clip opens the system's Photos
/// picker, which XCUITest can't drive; its rules are unit tested (`QuickEditReplaceClipTests`).
@MainActor
final class ExtractAudioUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testExtractAudioOfASilentClipSaysSoAndChangesNothing() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "edit")
        let undo = app.buttons["edit.undoButton"]
        let couldUndo = undo.isEnabled
        EditorApp.tapTool(app, "extractAudio")
        XCTAssertTrue(EditorApp.toastSays(app, "This clip has no sound", timeout: 10), "Extract audio on a silent clip said nothing")
        // Still the clip's tools, and nothing to undo.
        XCTAssertTrue(app.buttons["edit.toolbar.extractAudio"].exists)
        XCTAssertEqual(undo.isEnabled, couldUndo, "Extracting nothing added an undo step")
    }
}
