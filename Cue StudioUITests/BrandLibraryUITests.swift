//
//  BrandLibraryUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The creator's own things, from their side: Media › Your library shows what they kept, and a logo goes on in one tap, small
/// over the whole video, with Undo; ✦ Smart › Brand makes a kit from the video, saves it, and puts it on in one step; a kit and
/// the library are still there after Cue is closed and opened again.
@MainActor
final class BrandLibraryUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// Media › Your library: the sheet opens on it.
    private func openLibrary(_ app: XCUIApplication) {
        EditorApp.tapTool(app, "addMedia")
        EditorApp.tapTool(app, "mediaLibrary")
        let source = app.segmentedControls["edit.mediaSource"].buttons["Your library"]
        XCTAssertTrue(source.exists(within: 5), "No Your library in Add photo or video")
        XCTAssertTrue(source.isSelected, "Media › Your library didn't open on the library")
    }

    func testALogoFromTheLibraryGoesOnTheWholeVideoWithUndo() {
        let app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary"])
        openLibrary(app)
        let logo = app.buttons["edit.library.asset.Cue logo"]
        XCTAssertTrue(logo.exists(within: 5), "The seeded logo isn't in the library")
        XCTAssertTrue(app.buttons["edit.library.asset.Studio wall"].exists)
        EditorApp.capture(app, "library-all")
        // Filters and search narrow it.
        app.buttons["edit.library.filter"].tap()
        app.buttons["Logos"].tap()
        XCTAssertTrue(app.buttons["edit.library.asset.Studio wall"].isGone(within: 3))
        EditorApp.capture(app, "library-logos")
        logo.tap()
        EditorApp.capture(app, "logo-tapped")
        XCTAssertTrue(EditorApp.toastSays(app, "added over the whole video"))
        EditorApp.capture(app, "logo-on-video")
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(app.buttons["edit.redoButton"].isEnabled)
    }

    func testAKitFromThisVideoIsSavedAndPutOnInOneStep() {
        let root = "kits-\(UUID().uuidString)"
        var app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary", "-uiTestAssetRoot", root])
        EditorApp.tapTool(app, "brandKit")
        EditorApp.capture(app, "brand-empty")
        app.buttons["edit.brand.newKit"].tap()
        let name = app.textFields["edit.brand.kitName"]
        XCTAssertTrue(name.exists(within: 5))
        name.tap()
        name.clearAndType("Acme")
        EditorApp.capture(app, "kit-editor")
        app.buttons["edit.brand.saveKit"].tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Acme saved"))
        let card = app.buttons["edit.brand.kit.Acme"]
        XCTAssertTrue(card.exists(within: 5))
        card.tap()
        let apply = app.buttons["edit.brand.apply"]
        XCTAssertTrue(apply.exists(within: 5))
        XCTAssertTrue(app.buttons["edit.brand.part.textStyle"].exists)
        EditorApp.capture(app, "kit-apply")
        apply.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Acme on this video"))
        EditorApp.capture(app, "kit-applied")

        // Closed and opened again: the kit and the library are still there.
        app.terminate()
        app = EditorApp.open(demo: true, arguments: ["-uiTestAssetRoot", root])
        EditorApp.tapTool(app, "brandKit")
        XCTAssertTrue(app.buttons["edit.brand.kit.Acme"].exists(within: 5), "The kit didn't survive reopening")
    }

    /// In Portuguese the panel is "Kit de marca" (the owner's word), in Cue's own language even where the iPhone's differs, with
    /// the largest text its title whole, and it opens on its own: no tab to Templates (canvas 2 R3).
    func testTheBrandPanelSaysKitDeMarcaInPortugueseAtTheLargestText() {
        let app = EditorApp.open(arguments: [
            "-uiTestAppLanguage", "pt", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        EditorApp.tapTool(app, "brandKit")
        XCTAssertTrue(app.buttons["edit.brand.newKit"].exists(within: 5))
        XCTAssertTrue(app.staticTexts["Kit de marca"].exists, "The panel isn't called Kit de marca")
        XCTAssertFalse(app.buttons["edit.templates.section.templates"].exists, "Templates is still a tab of the brand kits")
        EditorApp.capture(app, "brand-panel-pt-xxxl")
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        if let value = value as? String, !value.isEmpty {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: value.count))
        }
        typeText(text)
    }
}
