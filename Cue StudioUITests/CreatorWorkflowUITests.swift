//
//  CreatorWorkflowUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The editor used end to end the way creators edit short vertical videos on a phone (CapCut and Edits grammar), on the
/// design's demo take (21.6 s, eight caption lines, a title and a subtitle, four pauses found): each step opens what it
/// says, nothing is a dead end, and every flow comes back to the main tools. Each flow prints its taps
/// (`CREATOR FLOW <name> · <n> taps`) to compare with CapCut. Run on the iPhone 17 and the iPhone SE
/// (`CUE_SIMULATOR="Cue v10 iPhone SE"`). The Simulator doesn't play the preview: the checks are on panels, sheets, toasts,
/// the timeline's length and the toolbar.
@MainActor
final class CreatorWorkflowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - 1. Talking head

    /// Pauses out, captions there and one word fixed, a hook on top, B-roll reachable, a cover, and Done.
    func testTalkingHeadFromPausesToPosting() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("talking-head", app: app)
        let fullLength = EditorApp.length(app)

        flow.step("✦ Smart › Remove pauses")
        flow.tool("smart")
        flow.tap(app.buttons["edit.smart.pauses"], "the Remove pauses tile")
        let firstPause = flow.element("edit.pause.0")
        let none = flow.element("edit.pauses.empty")
        XCTAssertTrue(flow.waits(for: firstPause, timeout: 10, "the pauses") || none.exists, "The Pauses panel found nothing to show")
        if firstPause.exists {
            let apply = app.buttons["edit.pauses.apply"]
            XCTAssertTrue(apply.label.hasPrefix("Remove"), apply.label)
            flow.tap(apply, apply.label)
            XCTAssertTrue(flow.toastSays("Removed"), "No toast after removing the pauses")
            XCTAssertNotEqual(EditorApp.length(app), fullLength, "Removing the pauses didn't shorten the video")
        } else {
            flow.tap(app.buttons["edit.panel.apply"], "✓")
        }
        XCTAssertTrue(flow.isOnMainTools(), "Removing the pauses didn't bring back the main tools")

        flow.step("Captions are there")
        flow.tool("captions")
        let line = flow.element("edit.captionLine.6")
        XCTAssertTrue(flow.waits(for: flow.element("edit.captionLine.0"), "the first caption line"))
        XCTAssertTrue(line.waitForExistence(timeout: 5), "No seventh caption line")

        flow.step("Fix a caption word (caudo → caldo)")
        // The line with the typo is further down the list: the thumb scrolls the panel to it.
        flow.scrollUp(to: line, from: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        flow.tap(line, "the line with “caudo”")
        let field = app.descendants(matching: .any).matching(identifier: "edit.captionField").firstMatch
        XCTAssertTrue(flow.waits(for: field, "the caption's field"))
        flow.tap(field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "No keyboard for the caption")
        flow.replaceText(of: field, with: "e caldo de cana do lado.")
        XCTAssertEqual(field.value as? String, "e caldo de cana do lado.")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Captions")
        flow.backToMainTools()
        // A check, not a creator's tap: the fix stayed once the panel closed.
        app.buttons["edit.toolbar.captions"].tap()
        let fixed = flow.element("edit.captionLine.6")
        XCTAssertTrue(fixed.waitForExistence(timeout: 5))
        let list = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        for _ in 0..<6 where !fixed.isHittable {
            list.press(forDuration: 0.05, thenDragTo: list.withOffset(CGVector(dx: 0, dy: -160)), withVelocity: 600, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(fixed.label.contains("caldo"), "The fixed word didn't stay: \(fixed.label)")
        app.buttons["edit.panel.apply"].tap()
        let back = app.buttons["edit.toolbar.back"]
        if back.waitForExistence(timeout: 2) { back.tap() }
        XCTAssertTrue(flow.isOnMainTools())

        flow.step("Text › Hook")
        flow.tool("text")
        flow.tool("hook")
        let hookField = app.textFields["edit.textField"]
        XCTAssertTrue(flow.waits(for: hookField, "the hook's field"))
        if !app.keyboards.firstMatch.waitForExistence(timeout: 2) { flow.tap(hookField, "the hook's field") }
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "No keyboard for the hook")
        flow.replaceText(of: hookField, with: "5 SP foods worth it")
        XCTAssertEqual(hookField.value as? String, "5 SP foods worth it")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on the hook")
        XCTAssertTrue(flow.waits(for: app.buttons["edit.toolbar.editText"], "the text's tools"), "The new hook isn't picked after ✓")
        flow.backToMainTools()

        flow.step("Media › on top of the video (B-roll)")
        flow.tool("addMedia")
        let mode = flow.element("edit.mediaMode")
        XCTAssertTrue(flow.waits(for: mode, "Add photo or video"), "Media didn't open Add photo or video")
        XCTAssertTrue(app.buttons["On top of video"].isSelected, "Media doesn't start on top of the video")
        let explanation = flow.element("edit.mediaModeExplanation")
        XCTAssertTrue(explanation.label.contains("B-roll"), explanation.label)
        flow.tap(app.buttons["sheet.closeButton"].firstMatch, "Add photo or video's ×")
        XCTAssertTrue(mode.waitForNonExistence(timeout: 5), "Add photo or video didn't go away")
        XCTAssertTrue(flow.isOnMainTools())

        flow.step("Cover Studio")
        flow.tool("cover")
        let coverDone = app.buttons["cover.done"]
        XCTAssertTrue(flow.waits(for: coverDone, "Cover Studio"), "Cover didn't open Cover Studio")
        XCTAssertTrue(app.images["cover.image"].waitForExistence(timeout: 10), "Cover Studio draws no cover")
        flow.tap(coverDone, "Cover Studio's Done")
        XCTAssertTrue(coverDone.waitForNonExistence(timeout: 5), "Cover Studio didn't close")
        XCTAssertTrue(flow.isOnMainTools())

        flow.step("Done › Ready to post")
        flow.tap(app.buttons["edit.doneButton"], "Done")
        flow.tap(app.buttons["edit.done.ready"], "“Ready”")
        XCTAssertTrue(app.buttons["review.editButton"].waitForExistence(timeout: 10), "Done didn't bring back the review")
        flow.report()
    }

    // MARK: - 2. Edit by text

    /// Two words out of the video by their text, and Undo in the toast brings them back.
    func testEditByTextCutsTwoWordsAndUndoBringsThemBack() throws {
        // The demo's words were heard already: the Simulator can't recognize speech.
        let app = EditorApp.open(demo: true, arguments: ["-uiTestDemoTranscript"])
        let flow = CreatorWorkflow("edit-by-text", app: app)
        let fullLength = EditorApp.length(app)

        flow.step("✦ Smart › Edit by text")
        flow.tool("smart")
        flow.tap(app.buttons["edit.smart.editByText"], "the Edit by text tile")
        XCTAssertTrue(flow.waits(for: flow.element("edit.transcript"), "Edit by text"), "Edit by text didn't open")
        let first = app.buttons["edit.transcript.word.2"]
        if !first.waitForExistence(timeout: 3) {
            // No words yet: Edit by text offers to listen to the video.
            flow.step("Listen to the video")
            flow.tap(app.buttons["edit.transcript.listen"], "Listen to the video")
            let replace = app.buttons["edit.captionsReplaceButton"]
            if replace.waitForExistence(timeout: 3) {
                print("CREATOR STEP edit-by-text · listening asks “Replace your edited captions?”")
                flow.capture("replace-question")
                flow.tap(replace, "Replace")
            }
            let heard = first.waitForExistence(timeout: 60)
            if !heard {
                flow.capture("no-words-after-listening")
                let toasts = app.descendants(matching: .any).matching(identifier: "toast").allElementsBoundByIndex.map(\.label)
                let listensAgain = app.buttons["edit.transcript.listen"].exists
                print("CREATOR STEP edit-by-text · no words after 60 s · toasts: \(toasts) · Listen offered again: \(listensAgain)")
            }
            if !heard {
                // Listening ended without words: the sheet must say why, never just offer the same button again.
                XCTAssertTrue(
                    app.descendants(matching: .any)["edit.transcript.problem"].waitForExistence(timeout: 5),
                    "Edit by text: listening found no words and the sheet didn't say why"
                )
                // The Simulator can't recognise speech: the cut itself is validated on the iPhone, not here.
                throw XCTSkip("No speech recognition here: cutting by text not validated in this run")
            }
        }

        flow.step("Pick two words")
        let second = app.buttons["edit.transcript.word.3"]
        let words = "\(first.label) \(second.label)"
        let guide = app.staticTexts["edit.transcript.pickGuide"]
        flow.tap(first, "the first word")
        // The first tap is the start of the part; the sheet says so and asks for the last word.
        XCTAssertTrue(flow.waits(for: guide, "the pick guide"))
        XCTAssertTrue(guide.label.hasPrefix("Start:"), guide.label)
        flow.tap(app.buttons["edit.transcript.pickAgain"], "Pick again")
        XCTAssertFalse(guide.waitForExistence(timeout: 1), "Pick again left a word picked")
        flow.tap(first, "the first word")
        flow.tap(second, "the second word")
        XCTAssertTrue(guide.label.hasPrefix("From"), guide.label)
        let cut = app.buttons["edit.transcript.cut"]
        XCTAssertTrue(flow.waits(for: cut, "Cut from video"))
        XCTAssertTrue(cut.label.contains("(2)"), cut.label)

        flow.step("Cut from video")
        flow.tap(cut, "Cut from video")
        XCTAssertTrue(flow.toastSays("2 words cut"), "No toast after cutting \(words)")
        XCTAssertNotEqual(EditorApp.length(app), fullLength, "Cutting \(words) didn't shorten the video")

        flow.step("Undo in the toast")
        let undo = flow.toastUndo
        XCTAssertNotNil(undo, "The toast's Undo can't be touched with Edit by text open")
        if let undo { flow.tap(undo, "Undo in the toast") }
        XCTAssertEqual(EditorApp.length(app), fullLength, "Undo didn't bring back \(words)")
        XCTAssertFalse(first.label.hasSuffix(", cut"), "The word stays crossed out after Undo")
        flow.report()
    }

    // MARK: - 3. Montage

    /// Split later in the take, copy the clip, see the clips in order, hold a frame, and a Zoom on every cut.
    func testMontageSplitDuplicateReorderFreezeAndATransitionOnEveryCut() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("montage", app: app)

        flow.step("Scrub, Edit › Split")
        flow.scrub()
        flow.tool("edit")
        flow.tool("split")
        XCTAssertTrue(flow.toastSays("Split at"), "No toast after Split")

        flow.step("Duplicate")
        flow.tool("duplicate")
        XCTAssertTrue(flow.toastSays("Clip duplicated"), "No toast after Duplicate")

        flow.step("Reorder")
        flow.tool("reorder")
        let list = flow.element("edit.reorder.list")
        XCTAssertTrue(flow.waits(for: list, "Reorder"), "Reorder didn't open")
        for index in 0..<3 {
            XCTAssertTrue(flow.element("edit.reorder.clip.\(index)").exists, "Reorder has no clip \(index + 1)")
        }
        flow.tap(app.buttons["sheet.closeButton"].firstMatch, "Reorder's ×")
        XCTAssertTrue(list.waitForNonExistence(timeout: 5), "Reorder didn't go away")
        XCTAssertTrue(flow.waits(for: app.buttons["edit.toolbar.freeze"], "the clip's tools"), "Reorder didn't come back to the clip's tools")

        flow.step("Freeze frame")
        flow.tool("freeze")
        XCTAssertTrue(flow.toastSays("Frame frozen", timeout: 15), "Freeze frame didn't freeze the frame")

        flow.step("Tap the cut › Zoom")
        // Freeze frame puts the playhead at the frozen frame's start: a cut, under the playhead. While a clip is picked the
        // timeline draws no cut marks (the picked clip's handles sit there; here the picked clip is the copy, off screen), so
        // a tap there picks a clip: ‹ back to the main tools first, then the cut's mark.
        flow.backToMainTools()
        flow.tap(EditorApp.mainTrack(app, at: 0.5))
        let zoom = app.buttons["edit.transition.zoom"]
        XCTAssertTrue(flow.waits(for: zoom, "the transitions"), "Tapping the cut didn't open the transitions")
        flow.tap(zoom, "Zoom")
        XCTAssertTrue(zoom.isSelected, "Zoom isn't marked")
        XCTAssertTrue(flow.element("edit.transition.duration").exists, "No Duration for Zoom")

        flow.step("Use on every cut")
        // Below the tiles and Duration: on a phone it is under the panel's fold until the panel is scrolled.
        let everyCut = app.buttons["edit.transition.everyCut"]
        flow.reveal(everyCut, "Use on every cut")
        flow.tap(everyCut, "Use on every cut")
        XCTAssertTrue(flow.toastSays("Zoom on every cut"), "No toast after Use on every cut")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on the transition")
        flow.backToMainTools()
        flow.report()
    }

    // MARK: - 4. Quick style

    /// A template, another, both undone; then a clip's look copied and pasted on every clip.
    func testQuickStyleTemplatesUndoThenCopyAndPasteALook() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("quick-style", app: app)

        flow.step("✦ Smart › Templates › Bold hook")
        flow.tool("smart")
        flow.tap(app.buttons["edit.smart.section.templates"], "the Templates tab")
        let boldHook = app.buttons["edit.template.boldHook"]
        flow.tap(boldHook, "Bold hook")
        XCTAssertTrue(flow.toastSays("Bold hook on the whole video"))
        XCTAssertTrue(boldHook.isSelected)

        flow.step("Story")
        let story = app.buttons["edit.template.story"]
        flow.reveal(story, "Story")
        flow.tap(story, "Story")
        XCTAssertTrue(flow.toastSays("Story on the whole video"))
        XCTAssertTrue(story.isSelected)
        XCTAssertFalse(boldHook.isSelected)

        flow.step("Undo twice")
        let undo = app.buttons["edit.undoButton"]
        flow.tap(undo, "Undo")
        XCTAssertTrue(boldHook.isSelected, "One Undo didn't go back to Bold hook")
        flow.tap(undo, "Undo")
        XCTAssertFalse(boldHook.isSelected, "Two Undos left Bold hook on")
        XCTAssertFalse(story.isSelected)
        flow.tap(app.buttons["edit.panel.apply"], "✓ on ✦ Smart")
        XCTAssertTrue(flow.isOnMainTools())

        flow.step("Split, a filter on the second clip")
        flow.scrub()
        flow.tool("edit")
        flow.tool("split")
        XCTAssertTrue(flow.toastSays("Split at"))
        flow.tool("filters")
        flow.tap(app.buttons["edit.filter.cinema"], "Cinema")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Filters")

        flow.step("Copy look")
        flow.tool("copyLook")
        XCTAssertTrue(flow.toastSays("Look copied"), "No toast after Copy look")

        flow.step("Paste look › Every clip")
        flow.tool("pasteLook")
        let everyClip = app.buttons["edit.pasteLook.all"]
        XCTAssertTrue(flow.waits(for: everyClip, "Paste look"), "Paste look didn't ask where")
        flow.tap(everyClip, "Every clip")
        XCTAssertTrue(flow.toastSays("Look pasted on every clip"), "No toast after pasting on every clip")
        XCTAssertTrue(everyClip.waitForNonExistence(timeout: 5))
        flow.backToMainTools()
        flow.report()
    }

    /// Copy look on a clip nobody changed, then Paste look › Every clip: the creator hears what happened (pasted, or nothing
    /// to paste), the button doesn't just close the sheet.
    func testPastingAnUntouchedLookOnEveryClipChangesNothing() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("paste-untouched-look", app: app)
        flow.step("Edit › Copy look › Paste look › Every clip")
        flow.tool("edit")
        flow.tool("copyLook")
        XCTAssertTrue(flow.toastSays("Look copied"))
        flow.tool("pasteLook")
        let everyClip = app.buttons["edit.pasteLook.all"]
        flow.tap(everyClip, "Every clip")
        XCTAssertTrue(everyClip.waitForNonExistence(timeout: 5))
        // Nothing changed: no undo step, the edit still unchanged. The toast that says so ("Every clip already looks like this")
        // shows over the editor and is announced to VoiceOver, but right after a sheet closes XCUITest's snapshot doesn't list
        // it; its words are checked in QuickEditCopyLookTests.aPasteThatChangesNothingSaysSo.
        XCTAssertTrue(app.buttons["edit.toolbar.pasteLook"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["edit.undoButton"].isEnabled, "Pasting an identical look added an undo step")
        flow.capture("after-every-clip")
        flow.report()
    }

    // MARK: - 5. Format

    /// Format on the main bar: 1:1, then back to 9:16.
    func testFormatSquareThenBackToVertical() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("format", app: app)
        let preview = flow.element("edit.preview")
        XCTAssertTrue(preview.waitForExistence(timeout: 5))

        flow.step("Format")
        flow.tool("format")
        XCTAssertTrue(flow.waits(for: app.staticTexts["Format"], "the Format panel"), "Format didn't open the Format panel")
        let vertical = app.buttons["edit.crop.9:16"]
        let square = app.buttons["edit.crop.1:1"]
        XCTAssertTrue(vertical.isSelected, "The take doesn't start at 9:16")

        flow.step("1:1")
        flow.tap(square, "1:1")
        XCTAssertTrue(square.isSelected, "1:1 isn't marked")
        XCTAssertFalse(vertical.isSelected)

        flow.step("Back to 9:16")
        flow.tap(vertical, "9:16")
        XCTAssertTrue(vertical.isSelected, "9:16 isn't marked")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Format")
        XCTAssertTrue(flow.isOnMainTools())
        flow.report()
    }
}
