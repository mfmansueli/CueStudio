//
//  MyFontsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// My fonts (owner, canvas 2 F12) on the demo, with a family the creator imported ("Qbrnd", `-uiTestImportedFont`): Text style ›
/// Font groups it with Edit; Edit puts a minus on it and a tap removes it with Undo; the title in it keeps it, still shown picked;
/// touching and holding the chip offers Remove too. Captured for the report.
@MainActor
final class MyFontsUITests: XCTestCase {
    private let family = "Qbrnd"

    override func setUp() {
        continueAfterFailure = false
    }

    private func undoOnToast(_ app: XCUIApplication) -> XCUIElement? {
        app.buttons.matching(identifier: "toast.action").allElementsBoundByIndex.first { $0.isHittable }
    }

    func testMyFontsEditRemovesWithUndoAndHoldingOffersRemove() {
        let app = EditorApp.open(demo: true, arguments: ["-uiTestImportedFont", family])
        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "styleAll")
        EditorApp.showTextTab(app, "font")
        let chip = app.buttons["edit.textFont.custom:\(family)"]
        XCTAssertTrue(chip.exists(within: 8), "No My fonts")
        XCTAssertTrue(app.staticTexts["My fonts"].exists)
        let edit = app.buttons["edit.textFont.myFonts.edit"]
        XCTAssertTrue(edit.exists, "No Edit in My fonts")

        // The title wears it, then Edit › remove: it leaves the picker, the title keeps it (still shown, nothing to remove).
        chip.tap()
        XCTAssertTrue(chip.isSelected)
        edit.tap()
        let remove = app.buttons["edit.textFont.remove.custom:\(family)"]
        XCTAssertTrue(remove.exists(within: 3), "Edit puts no minus on the chip")
        EditorApp.capture(app, "my-fonts-edit")
        remove.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "\(family) removed · videos that use it keep it"))
        XCTAssertTrue(chip.exists(within: 3) && chip.isSelected, "The title's font isn't shown any more")
        XCTAssertFalse(edit.exists, "Edit stays with nothing to remove")
        let undo = undoOnToast(app)
        XCTAssertNotNil(undo, "Removing has no Undo")
        undo?.tap()
        XCTAssertTrue(edit.exists(within: 3), "Undo didn't bring it back to My fonts")

        // Touch and hold: Remove from the chip's menu.
        chip.press(forDuration: 1.2)
        let menuRemove = app.buttons["Remove"].firstMatch
        XCTAssertTrue(menuRemove.exists(within: 3), "Holding the chip offers no Remove")
        EditorApp.capture(app, "my-fonts-hold")
        menuRemove.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "\(family) removed"))
    }
}
