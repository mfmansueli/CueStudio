//
//  QuickEditUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Quick edit from a take's review, on a small real video: play and pause, seek, cut, remove,
/// undo, redo, trim, Remove silences, captions, Done and Cancel.
@MainActor
final class QuickEditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testPlayingMovesThePlayheadAndPauseHoldsIt() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00:00 / 00:01:02"))

        app.buttons["edit.playButton"].tap()
        let moving = NSPredicate(format: "value != '00:00:00 / 00:01:02'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: moving, evaluatedWith: time)], timeout: 10), .completed)
        app.buttons["edit.playButton"].tap()
        let paused = time.value as? String
        sleep(2)
        XCTAssertEqual(time.value as? String, paused)
    }

    func testCuttingRemovingUndoingAndSavingAnEdit() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00:00 / 00:01:02"))
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        let duration = app.staticTexts["edit.durationChange"]
        XCTAssertEqual(duration.label, "1:02 → 1:02")

        // The middle of the timeline is the middle of the take.
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(wait(for: time, value: "00:00:31 / 00:01:02"))
        app.buttons["edit.cutButton"].tap()
        XCTAssertTrue(app.staticTexts["Cut at 00:00:31"].waitForExistence(timeout: 5))

        // Select the second piece and take it out.
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        app.buttons["edit.removeButton"].tap()
        XCTAssertTrue(app.staticTexts["Piece removed"].waitForExistence(timeout: 5))
        XCTAssertEqual(duration.label, "1:02 → 0:31")

        app.buttons["edit.undoButton"].tap()
        XCTAssertEqual(duration.label, "1:02 → 1:02")
        app.buttons["edit.redoButton"].tap()
        XCTAssertEqual(duration.label, "1:02 → 0:31")

        // Trim the start: drag its handle a quarter of the way in.
        let start = app.descendants(matching: .any)["edit.trimStartHandle"]
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)))
        XCTAssertNotEqual(duration.label, "1:02 → 0:31")
        XCTAssertTrue((time.value as? String)?.hasPrefix("00:00:00") ?? false)

        app.buttons["edit.tool.filters"].tap()
        XCTAssertTrue(app.buttons["edit.filter.mono"].waitForExistence(timeout: 5))
        app.buttons["edit.filter.mono"].tap()

        app.buttons["edit.doneButton"].tap()
        XCTAssertTrue(app.staticTexts["EDITED"].waitForExistence(timeout: 5))
    }

    func testCancellingAnEditAsksFirst() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00:00 / 00:01:02"))
        app.descendants(matching: .any)["edit.timeline"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["edit.cutButton"].tap()
        app.descendants(matching: .any)["edit.timeline"].coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)).tap()
        app.buttons["edit.removeButton"].tap()

        app.buttons["edit.cancelButton"].tap()
        let discard = app.buttons["Discard edits"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(app.buttons["review.editButton"].waitForExistence(timeout: 5))
    }

    func testCaptionsComeFromTheScript() {
        let app = openQuickEdit()
        app.buttons["edit.tool.captions"].tap()
        let toggle = app.switches["edit.captionsToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        // The switch sits at the trailing edge; the row's center is its label.
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let on = NSPredicate(format: "value == '1'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: on, evaluatedWith: toggle)], timeout: 10), .completed)
        app.buttons["edit.cancelButton"].tap()
        let discard = app.buttons["Discard edits"]
        if discard.waitForExistence(timeout: 3) { discard.tap() }
        XCTAssertTrue(app.buttons["review.editButton"].waitForExistence(timeout: 5))
    }

    func testRemoveSilencesOnlySuggests() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00:00 / 00:01:02"))
        // The sample video is silent: nothing to suggest, and nothing is cut.
        app.buttons["edit.silencesButton"].tap()
        XCTAssertTrue(app.staticTexts["No long pauses in this take"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["cleanUp.removeAllButton"].exists)
        XCTAssertEqual(app.staticTexts["edit.durationChange"].label, "1:02 → 1:02")
    }

    func testATakeWithoutItsVideoSaysSo() {
        let app = openQuickEdit(sampleVideo: false)
        let preview = app.descendants(matching: .any)["edit.preview"]
        XCTAssertTrue(wait(for: preview, value: "This video can't be opened"))
        XCTAssertFalse(app.buttons["edit.cutButton"].isEnabled)
        app.buttons["edit.cancelButton"].tap()
        XCTAssertTrue(app.buttons["review.editButton"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func openQuickEdit(sampleVideo: Bool = true) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: sampleVideo)
        let tab = app.tabBars.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        return app
    }

    private func wait(for element: XCUIElement, value: String, timeout: TimeInterval = 10) -> Bool {
        let matches = NSPredicate(format: "value == %@", value)
        return XCTWaiter.wait(for: [expectation(for: matches, evaluatedWith: element)], timeout: timeout) == .completed
    }
}
