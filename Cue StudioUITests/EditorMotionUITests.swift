//
//  EditorMotionUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The editor's motion tools on the sample take: Format › Follow face (it needs a format that crops), Stabilize on a clip,
/// Speed › Curve, and Reverse.
@MainActor
final class EditorMotionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFollowFaceTurnsOnInACroppingFormatAndHasAPace() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "format")
        let follow = app.descendants(matching: .any)["edit.crop.followFace"]
        XCTAssertTrue(follow.exists(within: 5))
        app.buttons["edit.crop.1:1"].tap()
        follow.tap()
        XCTAssertEqual(follow.value as? String, "On")
        let pace = app.buttons["edit.crop.followPace.calm"]
        XCTAssertTrue(pace.exists(within: 5))
        pace.tap()
        XCTAssertTrue(pace.isSelected)
        EditorApp.capture(app, "motion-follow-face")
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(app.buttons["edit.crop.followPace.natural"].isSelected)
    }

    func testStabilizeSpeedCurveAndReverseOnAClip() {
        let app = EditorApp.open()
        openClipTool(app, "stabilize")
        let standard = app.buttons["edit.stabilize.standard"]
        XCTAssertTrue(standard.exists(within: 5))
        standard.tap()
        XCTAssertTrue(standard.isSelected)
        EditorApp.capture(app, "motion-stabilize")
        app.buttons["edit.panel.apply"].tap()

        openClipTool(app, "speed")
        let curve = app.buttons["edit.speed.mode.curve"]
        XCTAssertTrue(curve.exists(within: 5))
        curve.tap()
        let hero = app.buttons["edit.speed.curve.hero"]
        XCTAssertTrue(hero.exists(within: 5))
        hero.tap()
        XCTAssertTrue(hero.isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["edit.speed.curvePoint.1"].exists)
        EditorApp.capture(app, "motion-speed-curve")
        app.buttons["edit.panel.apply"].tap()

        openClipTool(app, "reverse")
        XCTAssertTrue(EditorApp.toastSays(app, "Reversed", timeout: 30))
    }

    /// A tool of the clip under the playhead: Edit picks it when its tools aren't showing.
    private func openClipTool(_ app: XCUIApplication, _ id: String) {
        if !app.buttons["edit.toolbar.split"].exists {
            let edit = app.buttons["edit.toolbar.edit"]
            XCTAssertTrue(edit.exists(within: 5))
            edit.tap()
        }
        EditorApp.tapTool(app, id)
    }
}
