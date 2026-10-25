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
        let source = app.buttons["edit.mediaSource.library"]
        XCTAssertTrue(source.exists(within: 5), "No Your library in Add photo or video")
        source.tap()
    }

    func testALogoFromTheLibraryGoesOnTheWholeVideoWithUndo() {
        let app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary"])
        openLibrary(app)
        let logo = app.buttons["edit.library.asset.Cue logo"]
        XCTAssertTrue(logo.exists(within: 5), "The seeded logo isn't in the library")
        XCTAssertTrue(app.buttons["edit.library.asset.Studio wall"].exists)
        // Filters and search narrow it.
        app.buttons["edit.library.filter.logos"].tap()
        XCTAssertTrue(app.buttons["edit.library.asset.Studio wall"].isGone(within: 3))
        logo.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "added over the whole video"))
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(app.buttons["edit.redoButton"].isEnabled)
    }

    func testAKitFromThisVideoIsSavedAndPutOnInOneStep() {
        let root = "kits-\(UUID().uuidString)"
        var app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary", "-uiTestAssetRoot", root])
        EditorApp.tapTool(app, "smart")
        let brandTab = app.buttons["edit.smart.section.brand"]
        XCTAssertTrue(brandTab.exists(within: 5))
        brandTab.tap()
        app.buttons["edit.brand.newKit"].tap()
        let name = app.textFields["edit.brand.kitName"]
        XCTAssertTrue(name.exists(within: 5))
        name.tap()
        name.clearAndType("Acme")
        app.buttons["edit.brand.saveKit"].tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Acme saved"))
        let card = app.buttons["edit.brand.kit.Acme"]
        XCTAssertTrue(card.exists(within: 5))
        card.tap()
        let apply = app.buttons["edit.brand.apply"]
        XCTAssertTrue(apply.exists(within: 5))
        XCTAssertTrue(app.buttons["edit.brand.part.textStyle"].exists)
        apply.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Acme on this video"))

        // Closed and opened again: the kit and the library are still there.
        app.terminate()
        app = EditorApp.open(demo: true, arguments: ["-uiTestAssetRoot", root])
        EditorApp.tapTool(app, "smart")
        app.buttons["edit.smart.section.brand"].tap()
        XCTAssertTrue(app.buttons["edit.brand.kit.Acme"].exists(within: 5), "The kit didn't survive reopening")
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
