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
        EditorApp.captionsMenu(app, "edit.captionsFind").tap()
        let query = app.textFields["edit.captionFind.query"]
        XCTAssertTrue(query.exists(within: 5))
        query.typeText("caudo")
        let summary = app.staticTexts["edit.captionFind.summary"]
        XCTAssertTrue(summary.exists(within: 5))
        XCTAssertEqual(summary.label, "1 match")
        EditorApp.capture(app, "captions-find")
        let replacement = app.textFields["edit.captionFind.replacement"]
        replacement.tap()
        replacement.typeText("caldo")
        app.buttons["edit.captionFind.replaceAll"].tap()
        XCTAssertTrue(app.staticTexts["edit.captionFind.summary"].exists(within: 5))
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "No line says “caudo”")).firstMatch.exists(within: 5),
            "The word is still found after Replace all"
        )
        // The new word is found where the old one was.
        query.tap()
        app.buttons["Clear"].firstMatch.tap()
        query.typeText("caldo")
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label == %@", "1 match")).firstMatch.exists(within: 5),
            "The new word isn't in the line"
        )
    }

    /// My words: the list opens empty from Captions › •••, a word typed is added; in Find and replace, Add to My words names the
    /// spelling it saves (Replace with's), saves it without changing a line, and the word is then in the list.
    func testMyWordsKeepsAWordWithoutChangingTheCaptions() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "captions")
        EditorApp.captionsMenu(app, "edit.captionsMyWords").tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.myWords.empty"].exists(within: 5), "My words doesn't start empty")
        EditorApp.capture(app, "captions-my-words-empty")
        let field = app.textFields["edit.myWords.field"]
        field.tap()
        field.typeText("CapCut")
        app.buttons["edit.myWords.add"].tap()
        XCTAssertTrue(app.buttons["edit.myWords.word.CapCut"].exists(within: 5), "The word typed isn't in the list")
        EditorApp.capture(app, "captions-my-words")
        app.buttons["sheet.closeButton"].firstMatch.tap()

        EditorApp.captionsMenu(app, "edit.captionsFind").tap()
        let query = app.textFields["edit.captionFind.query"]
        XCTAssertTrue(query.exists(within: 5))
        query.typeText("caudo")
        let replacement = app.textFields["edit.captionFind.replacement"]
        replacement.tap()
        replacement.typeText("caldo")
        let add = app.buttons["edit.captionFind.addToMyWords"]
        XCTAssertTrue(add.exists(within: 5))
        XCTAssertEqual(add.label, "Add “caldo” to My words")
        EditorApp.capture(app, "captions-find-my-words")
        add.tap()
        XCTAssertTrue(
            app.buttons.matching(NSPredicate(format: "label == %@", "“caldo” is in My words")).firstMatch.exists(within: 5),
            "The button doesn't say the word is saved"
        )
        // Saving the word replaced nothing: the misheard word is still in its line.
        XCTAssertEqual(app.staticTexts["edit.captionFind.summary"].label, "1 match")
        app.buttons["sheet.closeButton"].firstMatch.tap()

        EditorApp.captionsMenu(app, "edit.captionsMyWords").tap()
        XCTAssertTrue(app.buttons["edit.myWords.word.caldo"].exists(within: 5), "Add to My words didn't save the word")
        XCTAssertTrue(app.buttons["edit.myWords.word.CapCut"].exists)
    }

    /// Select lines: all lines picked but the first, Emphasis on them, then deleted together; the first line stays. The actions
    /// stay pinned under the list.
    func testSelectedLinesAreStyledAndDeletedTogether() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "captions")
        EditorApp.captionsMenu(app, "edit.captionsSelect").tap()
        let count = app.staticTexts["edit.captionPicks.count"]
        XCTAssertTrue(count.exists(within: 5))
        XCTAssertEqual(count.label, "0 selected")
        app.buttons["edit.captionPicks.all"].tap()
        XCTAssertEqual(count.label, "8 selected")
        app.descendants(matching: .any)["edit.captionLine.0"].tap()
        XCTAssertEqual(count.label, "7 selected")
        let emphasis = app.descendants(matching: .any)["edit.captionPicks.emphasis"]
        XCTAssertTrue(emphasis.exists(within: 5))
        // The action and its reach; Highlight is the word being said's (owner, canvas 2 §7.1).
        XCTAssertTrue(emphasis.label.contains("Emphasize line"), "Select's whole-line emphasis reads \"\(emphasis.label)\"")
        emphasis.tap()
        XCTAssertTrue(["On", "1"].contains(emphasis.value as? String ?? ""), "Emphasis didn't turn on")
        EditorApp.capture(app, "captions-select")
        app.buttons["edit.captionPicks.delete"].tap()
        XCTAssertTrue(EditorApp.toastSays(app, "7 lines deleted"), "No toast after deleting the picked lines")
        XCTAssertFalse(app.staticTexts["edit.captionPicks.count"].exists, "Picking didn't end after Delete")
        XCTAssertTrue(app.descendants(matching: .any)["edit.captionLine.0"].exists(within: 5))
        XCTAssertFalse(app.descendants(matching: .any)["edit.captionLine.1"].exists, "The picked lines weren't deleted")
    }
}
