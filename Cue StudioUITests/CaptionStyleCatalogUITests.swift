//
//  CaptionStyleCatalogUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Caption style in four tabs, on the demo edit: Styles (filters kept, a style picked and checked, held for its menu, saved with
/// a name and deleted with Undo), Format (the size stays when another style is picked, and the style's own comes back on asking),
/// Animation and Adjust (a change over the style and "Back to its look"), and a word marked for emphasis in a line's More.
@MainActor
final class CaptionStyleCatalogUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func openCaptionStyle(_ app: XCUIApplication) {
        EditorApp.tapTool(app, "captions")
        let style = app.buttons["edit.captionsStyleButton"]
        XCTAssertTrue(style.exists(within: 5), "No Style in Captions")
        style.tap()
        XCTAssertTrue(app.buttons["edit.panel.tab.styles"].exists(within: 5), "No Styles tab")
    }

    private func tab(_ app: XCUIApplication, _ id: String) {
        let button = app.buttons["edit.panel.tab.\(id)"]
        XCTAssertTrue(button.exists(within: 5), "No \(id) tab")
        button.tap()
    }

    /// The filter chip `id`, brought into the window first (the row scrolls sideways).
    private func filter(_ app: XCUIApplication, _ id: String) {
        XCTAssertTrue(app.buttons["edit.captionFilter.all"].exists(within: 5), "No filters")
        let chip = app.buttons["edit.captionFilter.\(id)"]
        let window = app.windows.firstMatch.frame
        let row = app.scrollViews.allElementsBoundByIndex.first { $0.frame.height < 80 && $0.buttons["edit.captionFilter.all"].exists }
        for _ in 0..<5 where !chip.exists || chip.frame.maxX > window.maxX - 8 { row?.swipeLeft(velocity: .slow) }
        XCTAssertTrue(chip.exists(within: 5), "No \(id) filter")
        chip.tap()
    }

    /// Scrolls the panel up until `element` is drawn (cards and colors are made as they come into view).
    private func reveal(_ app: XCUIApplication, _ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let panel = app.descendants(matching: .any)["edit.panel.captionStyle"]
        for _ in 0..<6 where !element.exists || element.frame.maxY > app.windows.firstMatch.frame.maxY - 40 {
            panel.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(element.exists(within: 3), "\(element) isn't there", file: file, line: line)
    }

    private func waitFor(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    /// Impact's four styles; Comic picked is checked and said; the filter is there again when Caption style opens again; held,
    /// Comic goes to Favorites.
    func testAStyleIsPickedFromItsGroupAndTheFilterIsKept() {
        let app = EditorApp.open(demo: true)
        openCaptionStyle(app)
        filter(app, "impact")
        let comic = app.buttons["edit.captionPreset.comic"]
        XCTAssertTrue(comic.exists(within: 5), "Comic isn't under Impact")
        XCTAssertFalse(app.buttons["edit.captionPreset.cyanNight"].exists, "Impact shows another group's style")
        comic.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Comic on the captions"))
        XCTAssertTrue(waitFor { comic.isSelected }, "Comic isn't marked as picked")
        EditorApp.capture(app, "caption-styles-impact")
        app.buttons["edit.panel.apply"].tap()
        let back = app.buttons["edit.toolbar.back"]
        if back.exists(within: 2) { back.tap() }
        openCaptionStyle(app)
        XCTAssertTrue(app.buttons["edit.captionFilter.impact"].exists(within: 5))
        XCTAssertTrue(app.buttons["edit.captionFilter.impact"].isSelected, "The filter wasn't kept")
        comic.press(forDuration: 1)
        let favor = app.buttons["Add to favorites"]
        XCTAssertTrue(favor.exists(within: 5), "No menu on a held style")
        favor.tap()
        filter(app, "favorites")
        XCTAssertTrue(comic.exists(within: 5), "Comic isn't in Favorites")
    }

    /// Save style asks a name and the style shows in Mine, picked; held, it is deleted, and the toast's Undo brings it back.
    func testAStyleIsSavedWithANameAndDeletedWithUndo() {
        let app = EditorApp.open(demo: true)
        openCaptionStyle(app)
        filter(app, "mine")
        let save = app.buttons["edit.captionStyle.save"]
        XCTAssertTrue(save.exists(within: 5), "No Save style in Mine")
        save.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.exists(within: 5), "Save style doesn't ask a name")
        let field = alert.textFields.firstMatch
        XCTAssertEqual(field.value as? String, "My style", "The next free name isn't offered")
        field.tap()
        app.typeText(" weekly")
        alert.buttons["Save"].firstMatch.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Saved as My style weekly"))
        let saved = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.captionPreset.saved.'")).firstMatch
        XCTAssertTrue(saved.exists(within: 5), "The saved style isn't in Mine")
        XCTAssertTrue(saved.isSelected, "The captions wear the style just saved: it should be marked")
        EditorApp.capture(app, "caption-styles-mine")
        saved.press(forDuration: 1)
        // The card's menu (the editor's own Delete stays in its bar).
        let delete = app.collectionViews.buttons["Delete"].firstMatch
        XCTAssertTrue(delete.exists(within: 5), "No Delete in the saved style's menu")
        delete.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "My style weekly deleted"))
        XCTAssertTrue(saved.isGone(within: 3))
        // The editor's toast has its Undo; the app's own toast host under the editor shows one too, out of sight.
        let undo = app.buttons.matching(identifier: "toast.action").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(undo, "No Undo in the toast")
        undo?.tap()
        XCTAssertTrue(saved.exists(within: 5), "Undo didn't bring the style back")
    }

    /// Size L in Format, then Violet: the size stays, Styles says so and offers Violet's own, which brings it back to M.
    func testAnotherStyleKeepsTheSizeUntilItsOwnIsAskedFor() {
        let app = EditorApp.open(demo: true)
        openCaptionStyle(app)
        tab(app, "format")
        let large = app.buttons["edit.captionSize.2"]
        XCTAssertTrue(large.exists(within: 5))
        large.tap()
        XCTAssertTrue(large.isSelected)
        tab(app, "styles")
        filter(app, "colorful")
        app.buttons["edit.captionPreset.pop"].tap()
        let full = app.buttons["edit.captionStyle.full"]
        reveal(app, full)
        EditorApp.capture(app, "caption-styles-kept-size")
        tab(app, "format")
        XCTAssertTrue(app.buttons["edit.captionSize.2"].isSelected, "The size changed with the style")
        tab(app, "styles")
        reveal(app, full)
        full.tap()
        tab(app, "format")
        XCTAssertTrue(app.buttons["edit.captionSize.1"].isSelected, "The style's own size didn't come back")
    }

    /// Animation's three choices; Adjust changes the background over the style and "Back to its look" takes it away, with the
    /// motion and highlight color picked in Animation: the style comes back whole.
    func testAnimationAndAdjustChangeTheLookOverTheStyle() {
        let app = EditorApp.open(demo: true)
        openCaptionStyle(app)
        tab(app, "animation")
        let rise = app.buttons["edit.captionEntry.rise"]
        XCTAssertTrue(rise.exists(within: 5), "No In and out choices")
        rise.tap()
        XCTAssertTrue(rise.isSelected)
        app.buttons["edit.captionSpoken.glide"].tap()
        XCTAssertTrue(app.buttons["edit.captionSpoken.glide"].isSelected)
        reveal(app, app.buttons["edit.captionAccent.lavender"])
        EditorApp.capture(app, "caption-animation")
        tab(app, "adjust")
        let pill = app.buttons["edit.captionBackground.pill"]
        reveal(app, pill)
        pill.tap()
        XCTAssertTrue(pill.isSelected)
        let reset = app.buttons["edit.captionAdjust.reset"]
        reveal(app, reset)
        EditorApp.capture(app, "caption-adjust")
        reset.tap()
        XCTAssertTrue(reset.isGone(within: 3))
        reveal(app, app.buttons["edit.captionBackground.none"])
        XCTAssertTrue(app.buttons["edit.captionBackground.none"].isSelected)
        tab(app, "animation")
        XCTAssertTrue(app.buttons["edit.captionEntry.rise"].exists(within: 5))
        XCTAssertFalse(app.buttons["edit.captionEntry.rise"].isSelected, "The style's own way in didn't come back")
        XCTAssertFalse(app.buttons["edit.captionSpoken.glide"].isSelected, "The style's own word being said didn't come back")
        XCTAssertFalse(app.buttons["edit.captionAnimation.reset"].exists)
    }

    /// A line's More › Emphasis: a word marked stays marked, and Adjust then shows the emphasis color.
    func testAWordIsMarkedForEmphasis() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "captions")
        let line = app.descendants(matching: .any)["edit.captionLine.0"]
        XCTAssertTrue(line.exists(within: 5))
        line.tap()
        app.buttons["edit.captionMore"].tap()
        let strip = app.descendants(matching: .any)["edit.captionEmphasis"]
        XCTAssertTrue(strip.exists(within: 5), "No Emphasis in More")
        let word = strip.buttons.element(boundBy: 1)
        word.tap()
        XCTAssertTrue(waitFor { word.isSelected }, "The word isn't marked")
        EditorApp.capture(app, "caption-emphasis")
        app.buttons["edit.panel.apply"].tap()
        let back = app.buttons["edit.toolbar.back"]
        if back.exists(within: 2) { back.tap() }
        openCaptionStyle(app)
        tab(app, "adjust")
        reveal(app, app.buttons["edit.captionEmphasisSize.bigger"])
    }
}
