//
//  CaptionToolsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The caption tools that work on many lines at once, as CapCut's caption editor has them: Find and replace (a misheard word
/// fixed in every line), and Select (several lines styled, moved or deleted together). On the demo edit's eight lines.
@MainActor
final class CaptionToolsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// "caudo" was misheard: Find and replace finds it in its line and Replace all writes "caldo"; the new word is then found in its place.
    func testFindAndReplaceFixesAWordInEveryLine() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "captions")
        let find = app.buttons["edit.captionsFind"]
        XCTAssertTrue(find.waitForExistence(timeout: 5), "No Find and replace in Captions")
        find.tap()
        let query = app.textFields["edit.captionFind.query"]
        XCTAssertTrue(query.waitForExistence(timeout: 5))
        query.typeText("caudo")
        let summary = app.staticTexts["edit.captionFind.summary"]
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertEqual(summary.label, "1 match")
        let replacement = app.textFields["edit.captionFind.replacement"]
        replacement.tap()
        replacement.typeText("caldo")
        app.buttons["edit.captionFind.replaceAll"].tap()
        XCTAssertTrue(app.staticTexts["edit.captionFind.summary"].waitForExistence(timeout: 5))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "No line says “caudo”")).firstMatch.waitForExistence(timeout: 5),
            "The word is still found after Replace all"
        )
        // The new word is found where the old one was.
        query.tap()
        app.buttons["Clear"].firstMatch.tap()
        query.typeText("caldo")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "1 match")).firstMatch.waitForExistence(timeout: 5),
            "The new word isn't in the line"
        )
    }
}
