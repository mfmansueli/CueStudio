//
//  QuickEditUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Quick edit from a take's review, on a small real video: play and pause, seek, cut, delete,
/// remove part (and the zoom it brings), undo, redo, trim (straight through a cut), a cut's
/// transition, Clean Up, captions, Done, and Cancel keeping a draft.
@MainActor
final class QuickEditUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testPlayingMovesThePlayheadAndPauseHoldsIt() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00.00 / 01:02.00"))

        app.buttons["edit.playButton"].tap()
        let moving = NSPredicate(format: "value != '00:00.00 / 01:02.00'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: moving, evaluatedWith: time)], timeout: 10), .completed)
        app.buttons["edit.playButton"].tap()
        let paused = time.value as? String
        sleep(2)
        XCTAssertEqual(time.value as? String, paused)
    }

    func testCuttingDeletingUndoingAndSavingAnEdit() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00.00 / 01:02.00"))
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        let duration = app.staticTexts["edit.durationChange"]
        XCTAssertEqual(duration.label, "Original · 1:02")

        // The middle of the timeline is the middle of the take.
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(wait(for: time, value: "00:31.00 / 01:02.00"))
        app.buttons["edit.cutButton"].tap()
        XCTAssertTrue(app.staticTexts["Cut at 00:31.00 — tap a side, then Delete"].waitForExistence(timeout: 5))

        // The cut selects the second half: Delete takes it out.
        app.buttons["edit.removeButton"].tap()
        XCTAssertTrue(app.staticTexts["Section deleted"].waitForExistence(timeout: 5))
        XCTAssertEqual(duration.label, "1:02 → 0:31")

        app.buttons["edit.undoButton"].tap()
        XCTAssertEqual(duration.label, "Original · 1:02")
        app.buttons["edit.redoButton"].tap()
        XCTAssertEqual(duration.label, "1:02 → 0:31")

        // Trim the start: drag its handle a quarter of the way in.
        let start = app.descendants(matching: .any)["edit.trimStartHandle"]
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)))
        XCTAssertNotEqual(duration.label, "1:02 → 0:31")
        XCTAssertTrue((time.value as? String)?.hasPrefix("00:00") ?? false)

        app.buttons["edit.category.adjust"].tap()
        app.buttons["edit.tool.filters"].tap()
        XCTAssertTrue(app.buttons["edit.filter.mono"].waitForExistence(timeout: 5))
        app.buttons["edit.filter.mono"].tap()

        app.buttons["edit.doneButton"].tap()
        XCTAssertTrue(app.staticTexts["EDITED"].waitForExistence(timeout: 5))
    }

    func testBothHandlesTrimWithThePlayheadAtTheStart() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00.00 / 01:02.00"))
        let timeline = element(app, "edit.timeline")
        let duration = app.staticTexts["edit.durationChange"]
        let start = element(app, "edit.trimStartHandle")
        let end = element(app, "edit.trimEndHandle")

        // The playhead sits on the start handle at 00:00; the handle still moves.
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.25, dy: 0.5)))
        XCTAssertNotEqual(duration.label, "Original · 1:02")
        // It stays where it was let go, and goes back to the start from there.
        XCTAssertGreaterThan(start.frame.midX, timeline.frame.minX + timeline.frame.width * 0.15)
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: timeline.coordinate(withNormalizedOffset: CGVector(dx: 0, dy: 0.5)))
        XCTAssertEqual(duration.label, "Original · 1:02")

        end.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)))
        XCTAssertNotEqual(duration.label, "Original · 1:02")
        XCTAssertLessThan(end.frame.midX, timeline.frame.maxX - timeline.frame.width * 0.15)

        app.buttons["edit.undoButton"].tap()
        XCTAssertEqual(duration.label, "Original · 1:02")
    }

    func testTrimGoesStraightThroughACutAndACutCanFade() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00.00 / 01:02.00"))
        let timeline = element(app, "edit.timeline")
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(wait(for: time, value: "00:31.00 / 01:02.00"))
        app.buttons["edit.cutButton"].tap()

        // The cut's mark picks its transition: a hard cut ("None") until something else is chosen.
        let join = element(app, "edit.join.1")
        XCTAssertTrue(join.waitForExistence(timeout: 5))
        XCTAssertEqual(join.value as? String, "None")
        join.tap()
        let fade = app.buttons["edit.transition.fade"]
        XCTAssertTrue(fade.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit.transition.hardCut"].isSelected)
        fade.tap()
        XCTAssertTrue(fade.isSelected)
        app.buttons["edit.transitionDoneButton"].tap()
        XCTAssertTrue(app.buttons["edit.cutButton"].waitForExistence(timeout: 5))
        XCTAssertEqual(join.value as? String, "Fade")

        // The start handle dragged past the cut keeps trimming: the cut is not a barrier.
        let start = element(app, "edit.trimStartHandle")
        start.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.2, thenDragTo: timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)))
        let total = (time.value as? String)?.components(separatedBy: " / ").last ?? ""
        XCTAssertLessThan(total, "00:31.00")
        XCTAssertFalse(element(app, "edit.join.1").exists)

        // Undo brings the cut back, with its fade.
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(element(app, "edit.join.1").waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "edit.join.1").value as? String, "Fade")
    }

    func testRemovePartTakesOutTheRedRange() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00.00 / 01:02.00"))
        app.descendants(matching: .any)["edit.timeline"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(wait(for: time, value: "00:31.00 / 01:02.00"))

        app.buttons["edit.removePartButton"].tap()
        XCTAssertTrue(element(app, "edit.removalStartEdge").waitForExistence(timeout: 5))
        let confirm = app.buttons["edit.removePartConfirmButton"]
        XCTAssertTrue(confirm.label.contains("00:02.00"))
        confirm.tap()
        XCTAssertTrue(app.staticTexts["Removed 00:02.00"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["edit.durationChange"].label, "1:02 → 1:00")
        XCTAssertFalse(element(app, "edit.removalStartEdge").exists)
    }

    func testASmallRedRangeZoomsTheTimelineIn() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00.00 / 01:02.00"))
        let timeline = element(app, "edit.timeline")
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        XCTAssertTrue(wait(for: time, value: "00:31.00 / 01:02.00"))

        // Two seconds of a 1:02 take would be a few points wide: the timeline zooms in on them.
        app.buttons["edit.removePartButton"].tap()
        let start = element(app, "edit.removalStartEdge")
        let end = element(app, "edit.removalEndEdge")
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        let hint = app.staticTexts["edit.trimHint"]
        let zoomed = NSPredicate(format: "label BEGINSWITH 'Zoomed in' OR label BEGINSWITH 'Frame by frame'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: zoomed, evaluatedWith: hint)], timeout: 5), .completed)
        sleep(1)
        XCTAssertGreaterThan(end.frame.midX - start.frame.midX, timeline.frame.width * 0.3)
        XCTAssertGreaterThan(start.frame.midX, timeline.frame.minX)
        XCTAssertLessThan(end.frame.midX, timeline.frame.maxX)
        // Only the drawing changed: the range is still the same two seconds.
        XCTAssertTrue(app.buttons["edit.removePartConfirmButton"].label.contains("00:02.00"))

        // Without the range, back to the whole take.
        app.buttons["edit.removePartCancelButton"].tap()
        XCTAssertFalse(start.exists)
        let whole = NSPredicate(format: "label BEGINSWITH 'Tap to jump'")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: whole, evaluatedWith: hint)], timeout: 5), .completed)
    }

    func testCleanUpListensAndSuggestsWithoutCutting() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00.00 / 01:02.00"))
        app.buttons["edit.tool.cleanUp"].tap()
        // Pauses first; the words to review are in their own section.
        let review = app.segmentedControls["cleanUp.section"].buttons.element(boundBy: 1)
        XCTAssertTrue(review.waitForExistence(timeout: 5))
        review.tap()
        // The sample video is silent: nothing to suggest, and nothing is cut.
        XCTAssertTrue(element(app, "cleanUp.empty").waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["All clean"].exists)
        XCTAssertFalse(app.buttons["cleanUp.removeAllButton"].isEnabled)
        XCTAssertEqual(app.staticTexts["edit.durationChange"].label, "Original · 1:02")
    }

    func testCancelKeepsADraftThatEditPicksUp() {
        let app = openQuickEdit()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(wait(for: time, value: "00:00.00 / 01:02.00"))
        app.descendants(matching: .any)["edit.timeline"].coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        app.buttons["edit.cutButton"].tap()
        app.buttons["edit.removeButton"].tap()
        XCTAssertEqual(app.staticTexts["edit.durationChange"].label, "1:02 → 0:31")

        app.buttons["edit.cancelButton"].tap()
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["EDITED"].exists)
        edit.tap()
        XCTAssertTrue(app.staticTexts["Draft restored"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.staticTexts["edit.durationChange"].label, "1:02 → 0:31")
    }

    func testASilentTakeGetsNoInventedCaptionsAndCanBeCaptionedByHand() {
        let app = openQuickEdit()
        app.buttons["edit.category.captions"].tap()
        let toggle = app.switches["edit.captionsToggle"]
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        // The sample video is silent: captions say so instead of spreading the script over it.
        let status = app.staticTexts["edit.captionsStatus"]
        let silent = NSPredicate(format: "label == %@", "This take has no sound to caption.")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: silent, evaluatedWith: status)], timeout: 15), .completed)
        XCTAssertFalse(app.buttons["edit.captionLine"].exists)

        app.buttons["edit.captionsAddButton"].tap()
        let field = element(app, "captionSheet.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Three habits")
        app.buttons["captionSheet.done"].tap()
        let line = app.buttons["edit.captionLine"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        XCTAssertTrue(line.label.contains("Three habits"))
        app.buttons["edit.cancelButton"].tap()
        XCTAssertTrue(app.buttons["review.editButton"].waitForExistence(timeout: 5))
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

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func wait(for element: XCUIElement, value: String, timeout: TimeInterval = 10) -> Bool {
        let matches = NSPredicate(format: "value == %@", value)
        return XCTWaiter.wait(for: [expectation(for: matches, evaluatedWith: element)], timeout: timeout) == .completed
    }
}
