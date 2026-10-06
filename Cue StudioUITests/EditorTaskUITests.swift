//
//  EditorTaskUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The four tasks the v10 editor has to make obvious, on the design's demo take (21.6 s, eight
/// caption lines, a title and a subtitle, four pauses): cut a mistake (Split + Delete, and with a
/// handle), remove three of four pauses after listening to one, fix a caption and its end, and put
/// the Editorial preset on the title, then on every text. Run on the iPhone SE and a 6.1" iPhone.
@MainActor
final class EditorTaskUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// "Primeiro: o pastel do… não, pera." (7.1–10.1 with the pause after it) goes with Split at its
    /// start, Split at the next line, and Delete on the clip between.
    func testCuttingAMistakeWithSplitAndDelete() {
        let app = EditorApp.open(demo: true)
        XCTAssertEqual(EditorApp.length(app), "00:21.6")
        EditorApp.goToCaption(app, 3)
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "split")
        EditorApp.tapTool(app, "back")
        EditorApp.goToCaption(app, 4)
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "split")
        // The clip that ends at the playhead: just left of the middle.
        EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: -40, dy: 0)).tap()
        EditorApp.tapTool(app, "delete")
        XCTAssertEqual(EditorApp.length(app), "00:18.6")
        // Its caption is hidden, not deleted: undo brings it back.
        EditorApp.tapTool(app, "captions")
        XCTAssertTrue(app.descendants(matching: .any)["edit.captionLine.6"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["edit.captionLine.7"].exists)
        app.buttons["edit.panel.apply"].tap()
        app.buttons["edit.undoButton"].tap()
        XCTAssertEqual(EditorApp.length(app), "00:21.6")
    }

    /// The same mistake with the clip's left handle: Split at the line, then drag the start of the
    /// second clip to where the next line starts (3 s at 44 points a second).
    func testCuttingAMistakeWithAHandle() {
        let app = EditorApp.open(demo: true)
        EditorApp.goToCaption(app, 3)
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "split")
        // The second clip is picked; its left handle sits at the playhead.
        let handle = EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: -7, dy: 0))
        handle.press(forDuration: 0.2, thenDragTo: handle.withOffset(CGVector(dx: 132, dy: 0)), withVelocity: 250, thenHoldForDuration: 0.4)
        // About 3 s out (a finger isn't exact): the line with the mistake no longer plays.
        let length = EditorApp.length(app)
        XCTAssertTrue(length >= "00:18.3" && length <= "00:19.0", length)
        EditorApp.tapTool(app, "back")
        EditorApp.tapTool(app, "captions")
        XCTAssertTrue(app.descendants(matching: .any)["edit.captionLine.6"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.descendants(matching: .any)["edit.captionLine.7"].exists)
    }

    /// Listen to one pause, keep it, remove the other three.
    func testRemovingThreeOfFourPausesAfterListening() {
        let app = EditorApp.open(demo: true)
        EditorApp.openPauses(app)
        let first = app.descendants(matching: .any)["edit.pause.0"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        for index in 1...3 {
            XCTAssertTrue(app.descendants(matching: .any)["edit.pause.\(index)"].exists)
        }
        app.buttons["edit.pause.1.listen"].tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Playing without this pause"))
        // Keep the one heard, once it has played: real playback time (the listen button doesn't say when it ends).
        sleep(3)
        let card = app.descendants(matching: .any)["edit.pause.1"]
        card.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.25)).tap()
        let apply = app.buttons["edit.pauses.apply"]
        let three = NSPredicate(format: "label == %@", "Remove 3 pauses")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: three, object: apply)], timeout: 5), .completed, apply.label)
        apply.tap()
        XCTAssertEqual(EditorApp.length(app), "00:18.4")
    }

    /// "caudo" → "caldo", and the line ends 0.2 s later.
    func testFixingACaptionAndItsEnd() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "captions")
        let line = app.descendants(matching: .any)["edit.captionLine.6"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        line.tap()
        // The end first, before the keyboard comes up (More holds the timing).
        let more = app.buttons["edit.captionMore"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let later = app.buttons["edit.captionEnd.plus"]
        XCTAssertTrue(later.waitForExistence(timeout: 5))
        later.tap()
        later.tap()
        XCTAssertTrue(app.staticTexts["00:14.6 → 00:16.4"].waitForExistence(timeout: 3))
        let field = app.descendants(matching: .any).matching(identifier: "edit.captionField").firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        // The cursor at the end of the line, then everything out.
        field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)).tap()
        let text = (field.value as? String) ?? ""
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: text.count + 2))
        field.typeText("e caldo de cana do lado.")
        XCTAssertEqual(field.value as? String, "e caldo de cana do lado.")
    }

    /// Every caption goes at once, and Undo in the toast brings them back.
    func testDeletingAllCaptionsAtOnceCanBeUndone() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "captions")
        let first = app.descendants(matching: .any)["edit.captionLine.1"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        let deleteAll = app.buttons["edit.captionsDeleteAll"]
        XCTAssertTrue(deleteAll.waitForExistence(timeout: 5))
        deleteAll.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "lines deleted"))
        XCTAssertFalse(first.exists)
        // The editor's toast has its Undo; the app's own toast host under the editor shows one too,
        // out of sight, so the one tapped is the one on screen.
        let undo = app.buttons.matching(identifier: "toast.action").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertNotNil(undo)
        undo?.tap()
        XCTAssertTrue(first.waitForExistence(timeout: 5))
    }

    /// Logbook on the title only, then on every text.
    func testLogbookOnTheTitleThenOnEveryText() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "styleAll")
        let subtitle = app.staticTexts["edit.panel.subtitle"]
        XCTAssertTrue(subtitle.waitForExistence(timeout: 5))
        app.buttons["edit.style.scope.selected"].tap()
        XCTAssertEqual(subtitle.label, "Only this title changes")
        let logbook = app.buttons["edit.style.logbook"]
        XCTAssertFalse(logbook.isSelected)
        logbook.tap()
        XCTAssertTrue(logbook.isSelected)
        app.buttons["edit.style.scope.allTexts"].tap()
        XCTAssertEqual(subtitle.label, "All 2 texts change together")
        logbook.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Logbook on every text"))
        app.buttons["edit.panel.apply"].tap()
        XCTAssertTrue(app.buttons["edit.toolbar.back"].waitForExistence(timeout: 5))
    }

    /// The keyboard over the Text style panel: it opens, stays one panel (never a second copy, never a
    /// sheet), keeps the field, the scope and ✓ in reach, and neither closing the keyboard nor
    /// switching tabs closes the panel or loses what was typed. Repeated, because it used to flip the
    /// layout under the field and close the panel on the way.
    func testTypingInTheTextPanelKeepsOnePanelStableAndKeepsTheWords() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "styleAll")
        let panels = app.descendants(matching: .any).matching(identifier: "edit.panel.textStyle")
        XCTAssertTrue(panels.firstMatch.waitForExistence(timeout: 5))
        let field = app.textFields["edit.textField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        let apply = app.buttons["edit.panel.apply"]

        for round in 1...3 {
            field.tap()
            XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "round \(round)")
            // Give any layout flip the time it would have taken to show itself.
            XCTAssertFalse(app.buttons["edit.toolbar.edit"].waitForExistence(timeout: 1.5), "the panel closed, round \(round)")
            XCTAssertEqual(panels.count, 1, "a second panel, round \(round)")
            XCTAssertTrue(field.exists && apply.exists && app.buttons["edit.style.scope.selected"].exists, "round \(round)")
            // Over the keyboard, not under it.
            let keyboardTop = app.keyboards.firstMatch.frame.minY
            XCTAssertLessThanOrEqual(field.frame.maxY, keyboardTop + 1, "round \(round)")
            XCTAssertLessThanOrEqual(apply.frame.maxY, keyboardTop + 1, "round \(round)")

            field.typeText("ab")
            let typed = field.value as? String ?? ""
            XCTAssertTrue(typed.hasSuffix("ab"), "round \(round)")
            field.typeText(XCUIKeyboardKey.delete.rawValue)
            XCTAssertEqual(field.value as? String, String(typed.dropLast()), "round \(round)")
            field.typeText("b")
            XCTAssertEqual(field.value as? String, typed, "round \(round)")

            // Put the keyboard away with its Done key (Return): the panel and the words stay.
            field.typeText(XCUIKeyboardKey.return.rawValue)
            XCTAssertTrue(waitForGone(app.keyboards.firstMatch), "round \(round)")
            XCTAssertTrue(panels.firstMatch.exists && field.exists, "round \(round)")
            XCTAssertEqual(field.value as? String, typed, "round \(round)")
            // A tab of the style tools, and back to the field.
            app.buttons["edit.panel.tab.font"].tap()
            XCTAssertTrue(panels.firstMatch.exists && !app.buttons["edit.toolbar.edit"].exists)
            app.buttons["edit.panel.tab.presets"].tap()
        }
        apply.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.back"].waitForExistence(timeout: 5))
    }

    private func waitForGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !element.exists { return true }
            Thread.sleep(forTimeInterval: 0.1)
        }
        return false
    }
}
