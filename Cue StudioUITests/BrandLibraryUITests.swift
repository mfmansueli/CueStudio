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

    private func openLibrary(_ app: XCUIApplication) {
        EditorApp.tapTool(app, "addMedia")
        let source = app.segmentedControls["edit.mediaSource"].buttons["Your library"]
        XCTAssertTrue(source.exists(within: 5), "No Your library in Add photo or video")
        source.tap()
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

    /// The owner's report (25/10): a photo picked for the split screen got its "1" but never went in, because Continue was under
    /// the grid, off screen. Continue now stays over the bottom of the sheet from the first pick.
    func testAPickedPhotoGoesOnFromABarAlwaysInView() {
        let app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary"])
        openLibrary(app)
        XCTAssertTrue(app.staticTexts["edit.mediaPickHint"].exists(within: 3), "No hint on how to pick")
        let photo = app.buttons["edit.library.asset.Studio wall"]
        XCTAssertTrue(photo.exists(within: 5))
        photo.tap()
        let next = app.buttons["edit.mediaContinue"]
        XCTAssertTrue(next.exists(within: 3), "No Continue after a pick")
        XCTAssertTrue(next.isHittable, "Continue is off screen")
        XCTAssertTrue(app.windows.firstMatch.frame.contains(next.frame), "Continue isn't on the screen")
        EditorApp.capture(app, "library-picked")
        next.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "split screen", timeout: 5), "The photo never went in")
    }

    func testAKitFromThisVideoIsSavedAndPutOnInOneStep() {
        let root = "kits-\(UUID().uuidString)"
        var app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary", "-uiTestAssetRoot", root])
        EditorApp.tapTool(app, "smart")
        let brandTab = app.buttons["edit.smart.section.brand"]
        XCTAssertTrue(brandTab.exists(within: 5))
        brandTab.tap()
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
        EditorApp.tapTool(app, "smart")
        app.buttons["edit.smart.section.brand"].tap()
        XCTAssertTrue(app.buttons["edit.brand.kit.Acme"].exists(within: 5), "The kit didn't survive reopening")
    }

    /// In Portuguese the tab is "Kit de marca" (the owner's word), in Cue's own language even where the iPhone's differs, and with
    /// the largest text it takes two lines in its segment rather than being cut.
    func testTheBrandTabSaysKitDeMarcaInPortugueseAtTheLargestText() {
        let app = EditorApp.open(arguments: [
            "-uiTestAppLanguage", "pt", "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL",
        ])
        EditorApp.tapTool(app, "smart")
        let tab = app.buttons["edit.smart.section.brand"]
        XCTAssertTrue(tab.exists(within: 5))
        XCTAssertEqual(tab.label, "Kit de marca")
        XCTAssertTrue(tab.isHittable)
        EditorApp.capture(app, "brand-tab-pt-xxxl")
        tab.tap()
        XCTAssertTrue(app.buttons["edit.brand.newKit"].exists(within: 5))
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
