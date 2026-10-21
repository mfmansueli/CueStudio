//
//  EyeContactUITests.swift
//  Cue StudioUITests
//

import XCTest

/// ✦ Smart › Eye Contact: off by default, its own panel from the Smart tile, turned on with one tap (one undo step), Before/After
/// by tap, an honest line on where it stands, and back to ✦ Smart. The Simulator's Vision finds no faces, so the line ends on
/// "no face" here; the correction itself is checked on the iPhone (`EyeContactDeviceTests`).
@MainActor
final class EyeContactUITests: XCTestCase {
    override func setUp() async throws {
        continueAfterFailure = false
    }

    private func openPanel(_ app: XCUIApplication) -> XCUIElement {
        EditorApp.tapTool(app, "smart")
        tapTile(app)
        let panel = app.descendants(matching: .any)["edit.panel.eyeContact"]
        XCTAssertTrue(panel.exists(within: 5))
        return panel
    }

    /// The Eye Contact tile, scrolled into view (it's the last of the row) and tapped.
    private func tapTile(_ app: XCUIApplication) {
        let tile = app.buttons["edit.smart.eyeContact"]
        XCTAssertTrue(tile.exists(within: 5))
        var swipes = 0
        while !app.windows.firstMatch.frame.contains(tile.frame), swipes < 4 {
            app.buttons["edit.smart.voice"].swipeLeft()
            swipes += 1
        }
        tile.tap()
    }

    func testTurningEyeContactOnFromSmart() {
        let app = EditorApp.open()
        _ = openPanel(app)
        let toggle = app.toggles["edit.eyeContact.toggle"]
        XCTAssertTrue(toggle.exists(within: 5))
        XCTAssertEqual(toggle.value as? String, "Off")
        XCTAssertFalse(app.descendants(matching: .any)["edit.eyeContact.strength"].exists)
        toggle.tap()
        XCTAssertEqual(toggle.value as? String, "On")
        XCTAssertTrue(app.descendants(matching: .any)["edit.eyeContact.strength"].exists(within: 5))
        // Where it stands, in words (finding the eyes, then what came of it).
        XCTAssertTrue(app.staticTexts["edit.eyeContact.status"].exists(within: 10))
        // Before / After with a tap.
        let before = app.buttons["edit.eyeContact.compare.before"]
        XCTAssertTrue(before.exists(within: 5))
        before.tap()
        XCTAssertTrue(before.isSelected)
        app.buttons["edit.eyeContact.compare.after"].tap()
        XCTAssertFalse(before.isSelected)
        // Back to the other tools: the tile says it's on.
        app.buttons["edit.eyeContact.back"].tap()
        let tile = app.buttons["edit.smart.eyeContact"]
        XCTAssertTrue(tile.exists(within: 5))
        XCTAssertTrue(app.buttons["edit.smart.voice"].exists)
        // One undo turns it off again.
        app.buttons["edit.undoButton"].tap()
        tapTile(app)
        XCTAssertEqual(app.toggles["edit.eyeContact.toggle"].value as? String, "Off")
    }

    /// Pictures and accessibility trees of the panel for `tools/contrast/audit.py` (off, on with its status line, Before), at the
    /// default text size and at the largest accessibility size. Opt in with `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`.
    func testCapturesForContrast() throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        for (size, arguments) in [("default", [String]()), ("ax5", ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])] {
            let app = EditorApp.open(arguments: arguments)
            func shot(_ name: String) throws {
                sleep(1)
                try app.screenshot().pngRepresentation.write(to: folder.appending(path: "eyecontact-\(size)-\(name).png"))
                try app.debugDescription.write(to: folder.appending(path: "eyecontact-\(size)-\(name).txt"), atomically: true, encoding: .utf8)
            }
            _ = openPanel(app)
            try shot("off")
            app.toggles["edit.eyeContact.toggle"].tap()
            XCTAssertTrue(app.staticTexts["edit.eyeContact.status"].exists(within: 10))
            try shot("on")
            app.buttons["edit.eyeContact.compare.before"].tap()
            try shot("before")
            app.buttons["edit.eyeContact.back"].tap()
            try shot("smart")
            app.terminate()
        }
    }
}
