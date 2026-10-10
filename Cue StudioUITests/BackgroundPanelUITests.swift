//
//  BackgroundPanelUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Quick edit › Background, reorganized: the background (Original, Blur, Color, Image) with only the picked one's control under it; the
/// Cutout in its own card (Automatic, or a green or blue screen with its color and, folded, Tolerance, Edge and Spill); the subtitle saying
/// the scope and what is behind the creator; values kept while switching; undo; ✓ in reach while the content scrolls, and the last line
/// clear of the Home Indicator.
@MainActor
final class BackgroundPanelUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func panel(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any)["edit.panel.background"]
    }

    private func subtitle(_ app: XCUIApplication) -> String {
        panel(app).staticTexts["edit.panel.subtitle"].label
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Scrolls the panel's content (slowly: a quick swipe didn't move it) until `target` shows above the screen's bottom. `up` for what
    /// is above: the tiles are in a lazy grid, so scrolled past they leave the hierarchy and can't say where they are.
    private func scroll(_ app: XCUIApplication, to target: XCUIElement, up: Bool = false, file: StaticString = #filePath, line: UInt = #line) {
        let bottom = app.windows.firstMatch.frame.maxY
        for _ in 0..<8 where !(target.exists && target.frame.maxY <= bottom && target.isHittable) {
            let content = panel(app).scrollViews.firstMatch
            if up || (target.exists && target.frame.maxY < content.frame.minY) {
                content.swipeDown(velocity: .slow)
            } else {
                content.swipeUp(velocity: .slow)
            }
        }
        XCTAssertTrue(target.waitForExistence(timeout: 3), "\(target) isn't there", file: file, line: line)
    }

    private func waitFor(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    func testTheBackgroundComesFirstAndTheCutoutIsItsOwnPart() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "background")
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5))
        XCTAssertTrue(subtitle(app).hasSuffix("As recorded"), subtitle(app))
        for style in ["original", "blur", "color", "image"] {
            XCTAssertTrue(app.buttons["edit.background.\(style)"].exists, style)
        }
        XCTAssertTrue(element(app, "edit.backgroundCutoutCard").exists)
        XCTAssertFalse(element(app, "edit.backgroundBlur").exists, "Original has no control of its own")

        // Only the picked background's control shows under the tiles.
        app.buttons["edit.background.blur"].tap()
        XCTAssertTrue(element(app, "edit.backgroundBlur").waitForExistence(timeout: 3))
        XCTAssertFalse(app.buttons["edit.backgroundColor.red"].exists)
        XCTAssertTrue(waitFor { self.subtitle(app).hasSuffix("Blur behind you") }, subtitle(app))
        app.buttons["edit.background.color"].tap()
        XCTAssertTrue(app.buttons["edit.backgroundColor.red"].waitForExistence(timeout: 3))
        XCTAssertFalse(element(app, "edit.backgroundBlur").exists)
        app.buttons["edit.backgroundColor.red"].tap()
        XCTAssertTrue(waitFor { self.subtitle(app).hasSuffix("Color behind you") }, subtitle(app))

        // The cutout: automatic by default; the green or blue screen shows its color, and its fine-tuning stays folded until asked.
        let screen = app.buttons["edit.backgroundCutout.colorKey"]
        scroll(app, to: screen)
        XCTAssertTrue(app.buttons["edit.backgroundCutout.person"].isSelected)
        XCTAssertFalse(app.buttons["edit.keyColor.green"].exists)
        screen.tap()
        XCTAssertTrue(waitFor { self.subtitle(app).hasSuffix("Color on the green or blue screen") }, subtitle(app))
        let green = app.buttons["edit.keyColor.green"]
        scroll(app, to: green)
        XCTAssertTrue(green.isSelected)
        XCTAssertFalse(element(app, "edit.keyTolerance").exists, "Tolerance, Edge and Spill start folded")
        let fineTune = app.buttons["edit.backgroundFineTune"]
        scroll(app, to: fineTune)
        fineTune.tap()
        for id in ["edit.keyTolerance", "edit.keySoftness", "edit.keySpill"] {
            scroll(app, to: element(app, id))
        }
        scroll(app, to: app.buttons["edit.keyColor.blue"])
        app.buttons["edit.keyColor.blue"].tap()

        // Back to Automatic and to the screen again: the screen's color is still blue, and the color still red.
        let automatic = app.buttons["edit.backgroundCutout.person"]
        scroll(app, to: automatic)
        automatic.tap()
        XCTAssertTrue(waitFor { !app.buttons["edit.keyColor.blue"].exists })
        app.buttons["edit.backgroundCutout.colorKey"].tap()
        scroll(app, to: app.buttons["edit.keyColor.blue"])
        XCTAssertTrue(app.buttons["edit.keyColor.blue"].isSelected, "the screen's color stays")
        let top = app.buttons["edit.background.color"]
        scroll(app, to: top, up: true)
        XCTAssertTrue(top.isSelected)

        // Undo takes back the last change (back to Automatic), and ✓ is in reach the whole time.
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(waitFor { self.subtitle(app).hasSuffix("Color behind you") }, subtitle(app))
        let apply = app.buttons["edit.panel.apply"]
        XCTAssertTrue(apply.isHittable)
        apply.tap()
        XCTAssertTrue(waitFor { !self.panel(app).exists })
    }

    /// The last line says changes are saved as they're made and ✓ closes; scrolled to it, it stops above the Home Indicator.
    func testTheLastLineIsClearOfTheHomeIndicator() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "background")
        XCTAssertTrue(panel(app).waitForExistence(timeout: 5))
        app.buttons["edit.background.color"].tap()
        scroll(app, to: app.buttons["edit.backgroundCutout.colorKey"])
        app.buttons["edit.backgroundCutout.colorKey"].tap()
        let note = element(app, "edit.backgroundSaveNote")
        scroll(app, to: note)
        for _ in 0..<3 { panel(app).scrollViews.firstMatch.swipeUp(velocity: .slow) }
        let window = app.windows.firstMatch.frame
        // The Home Indicator's area (34 pt on a Face ID iPhone; the SE has none) and the panel's clearance above it (18 pt).
        let homeIndicator: CGFloat = window.height > 700 ? 34 : 0
        XCTAssertLessThanOrEqual(note.frame.maxY, window.maxY - homeIndicator - 18 + 1, "\(note.frame) in \(window)")
        XCTAssertTrue(app.buttons["edit.panel.apply"].isHittable)
    }
}
