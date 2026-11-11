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

        flow.step("Clean up › Pauses")
        flow.tool("pauses")
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
        XCTAssertTrue(line.exists(within: 5), "No seventh caption line")

        flow.step("Fix a caption word (caudo → caldo)")
        // The line with the typo is further down the list: the thumb scrolls the panel to it.
        flow.scrollUp(to: line, from: app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9)))
        flow.tap(line, "the line with “caudo”")
        let field = app.descendants(matching: .any).matching(identifier: "edit.captionField").firstMatch
        XCTAssertTrue(flow.waits(for: field, "the caption's field"))
        flow.tap(field.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.5)))
        XCTAssertTrue(app.keyboards.firstMatch.exists(within: 5), "No keyboard for the caption")
        flow.replaceText(of: field, with: "e caldo de cana do lado.")
        // Each key re-times the line, so the last keys can still be landing when typing returns: wait for them, never for less.
        let typed = NSPredicate(format: "value == %@", "e caldo de cana do lado.")
        XCTAssertTrue(field.matches(typed, within: 5), "The field has “\(field.value as? String ?? "")”")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Captions")
        flow.backToMainTools()
        // A check, not a creator's tap: the fix stayed once the panel closed.
        app.buttons["edit.toolbar.captions"].tap()
        let fixed = flow.element("edit.captionLine.6")
        XCTAssertTrue(fixed.exists(within: 5))
        let list = app.windows.firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.9))
        for _ in 0..<6 where !fixed.isHittable {
            list.press(forDuration: 0.05, thenDragTo: list.withOffset(CGVector(dx: 0, dy: -160)), withVelocity: 600, thenHoldForDuration: 0.2)
        }
        XCTAssertTrue(fixed.label.contains("caldo"), "The fixed word didn't stay: \(fixed.label)")
        app.buttons["edit.panel.apply"].tap()
        let back = app.buttons["edit.toolbar.back"]
        if back.exists(within: 2) { back.tap() }
        XCTAssertTrue(flow.isOnMainTools())

        flow.step("Text › Hook")
        flow.tool("text")
        flow.tool("hook")
        let hookField = app.textFields["edit.textField"]
        XCTAssertTrue(flow.waits(for: hookField, "the hook's field"))
        if !app.keyboards.firstMatch.exists(within: 2) { flow.tap(hookField, "the hook's field") }
        XCTAssertTrue(app.keyboards.firstMatch.exists(within: 5), "No keyboard for the hook")
        flow.replaceText(of: hookField, with: "5 SP foods worth it")
        XCTAssertEqual(hookField.value as? String, "5 SP foods worth it")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on the hook")
        XCTAssertTrue(flow.waits(for: app.buttons["edit.toolbar.editText"], "the text's tools"), "The new hook isn't picked after ✓")
        flow.backToMainTools()

        flow.step("Media › Full screen (B-roll), from the Media bar")
        flow.tool("addMedia")
        flow.tool("mediaFullScreen")
        let mode = flow.element("edit.mediaMode")
        XCTAssertTrue(flow.waits(for: mode, "Add photo or video"), "Media › Full screen didn't open Add photo or video")
        XCTAssertTrue(app.buttons["edit.mediaMode.fullScreen"].isSelected, "The sheet doesn't open on Full screen")
        let explanation = flow.element("edit.mediaModeExplanation")
        XCTAssertTrue(explanation.label.contains("voice goes on"), explanation.label)
        flow.tap(app.buttons["sheet.closeButton"].firstMatch, "Add photo or video's ×")
        XCTAssertTrue(mode.isGone(within: 5), "Add photo or video didn't go away")
        XCTAssertTrue(app.buttons["edit.toolbar.mediaSplit"].exists, "Not back on the Media bar")
        flow.backToMainTools()

        flow.step("Cover Studio")
        flow.tool("cover")
        let coverDone = app.buttons["cover.done"]
        XCTAssertTrue(flow.waits(for: coverDone, "Cover Studio"), "Cover didn't open Cover Studio")
        XCTAssertTrue(app.images["cover.image"].exists(within: 10), "Cover Studio draws no cover")
        flow.tap(coverDone, "Cover Studio's Done")
        XCTAssertTrue(coverDone.isGone(within: 5), "Cover Studio didn't close")
        XCTAssertTrue(flow.isOnMainTools())

        flow.step("Done › Ready to post")
        flow.tap(app.buttons["edit.doneButton"], "Done")
        flow.tap(app.buttons["edit.done.ready"], "“Ready”")
        XCTAssertTrue(app.buttons["review.editButton"].exists(within: 10), "Done didn't bring back the review")
        flow.report()
    }

    // MARK: - 2. Edit by text

    /// Two words out of the video by their text, and Undo in the toast brings them back.
    func testEditByTextCutsTwoWordsAndUndoBringsThemBack() throws {
        // The demo's words were heard already: the Simulator can't recognize speech.
        let app = EditorApp.open(demo: true, arguments: ["-uiTestDemoTranscript"])
        let flow = CreatorWorkflow("edit-by-text", app: app)
        let fullLength = EditorApp.length(app)

        flow.step("Edit by text")
        flow.tool("editByText")
        XCTAssertTrue(flow.waits(for: flow.element("edit.transcript"), "Edit by text"), "Edit by text didn't open")
        let first = app.buttons["edit.transcript.word.2"]
        if !first.exists(within: 3) {
            // No words yet: Edit by text offers to listen to the video.
            flow.step("Listen to the video")
            flow.tap(app.buttons["edit.transcript.listen"], "Listen to the video")
            let replace = app.buttons["edit.captionsReplaceButton"]
            if replace.exists(within: 3) {
                print("CREATOR STEP edit-by-text · listening asks “Replace your edited captions?”")
                flow.capture("replace-question")
                flow.tap(replace, "Replace")
            }
            let heard = first.exists(within: 60)
            if !heard {
                flow.capture("no-words-after-listening")
                let toasts = app.descendants(matching: .any).matching(identifier: "toast").allElementsBoundByIndex.map(\.label)
                let listensAgain = app.buttons["edit.transcript.listen"].exists
                print("CREATOR STEP edit-by-text · no words after 60 s · toasts: \(toasts) · Listen offered again: \(listensAgain)")
            }
            if !heard {
                // Listening ended without words: the sheet must say why, never just offer the same button again.
                XCTAssertTrue(
                    app.descendants(matching: .any)["edit.transcript.problem"].exists(within: 5),
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
        XCTAssertFalse(guide.exists(within: 1), "Pick again left a word picked")
        flow.tap(first, "the first word")
        flow.tap(second, "the second word")
        XCTAssertTrue(guide.label.hasPrefix("From"), guide.label)
        let cut = app.buttons["edit.transcript.cut"]
        XCTAssertTrue(flow.waits(for: cut, "Cut from video"))
        XCTAssertTrue(cut.label.contains("2 words"), cut.label)

        flow.step("Cut from video, then Undo in its toast")
        flow.tap(cut, "Cut from video")
        XCTAssertTrue(flow.toastSays("2 words cut"), "No toast after cutting \(words)")
        XCTAssertNotEqual(EditorApp.length(app), fullLength, "Cutting \(words) didn't shorten the video")
        // The toast stays 4 s and is drawn once, by the editor (a second one fails the tap): its Undo, over Edit by text, is touched
        // right after, since on a busy Mac each look at the screen takes up to a second (11/11/2026: looking for it among the toast's
        // copies, then waiting for it to be hittable, outlasted the toast).
        flow.tapNow(app.buttons["toast.action"])
        XCTAssertEqual(EditorApp.length(app), fullLength, "Undo didn't bring back \(words)")
        XCTAssertFalse(first.label.hasSuffix(", cut"), "The word stays crossed out after Undo")
        flow.report()
    }

    // MARK: - 3. Montage

    /// Split later in the take, copy the clip, see the clips in order, hold a frame, a Zoom on every cut, and Punch in on cuts.
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
        XCTAssertTrue(flow.toastSays("duplicated"), "No toast after Duplicate")

        flow.step("Reorder")
        flow.tool("reorder")
        let list = flow.element("edit.reorder.list")
        XCTAssertTrue(flow.waits(for: list, "Reorder"), "Reorder didn't open")
        for index in 0..<3 {
            XCTAssertTrue(flow.element("edit.reorder.clip.\(index)").exists, "Reorder has no clip \(index + 1)")
        }
        flow.tap(app.buttons["sheet.closeButton"].firstMatch, "Reorder's ×")
        XCTAssertTrue(list.isGone(within: 5), "Reorder didn't go away")
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
        XCTAssertTrue(flow.toastSays("Zoom on all"), "No toast after Use on every cut")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on the transition")
        flow.backToMainTools()

        flow.step("A clip › Zoom › Punch in on cuts")
        // One switch for the whole video, at the foot of the clip's Zoom (R1.3: it took a Punch in and a Paste look per clip).
        flow.tap(EditorApp.mainTrack(app, at: 0.15))
        flow.tool("zoom")
        // A row with the toggle trait: not a button nor a switch to XCUITest, found by its identifier.
        let cuts = flow.element("edit.zoom.cuts")
        flow.reveal(cuts, "Punch in on cuts")
        flow.tap(cuts, "Punch in on cuts")
        XCTAssertTrue(flow.toastSays("Punch in on"), "No toast after Punch in on cuts")
        XCTAssertTrue(flow.element("edit.zoom.cutsStrength.medium").exists, "No strength once Punch in on cuts is on")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Zoom")
        flow.backToMainTools()
        flow.report()
    }

    // MARK: - 4. Quick style

    /// A template, another, both undone; then a clip's look copied and pasted on every clip.
    func testQuickStyleTemplatesUndoThenCopyAndPasteALook() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("quick-style", app: app)

        flow.step("Templates › Bold hook")
        flow.tool("templates")
        let boldHook = app.buttons["edit.template.boldHook"]
        flow.tap(boldHook, "Bold hook")
        flow.tap(app.buttons["edit.template.apply"], "Apply")
        XCTAssertTrue(flow.toastSays("Bold hook on the whole video"))
        XCTAssertTrue(boldHook.isSelected)

        flow.step("Story")
        let story = app.buttons["edit.template.story"]
        flow.reveal(story, "Story")
        flow.tap(story, "Story")
        flow.tap(app.buttons["edit.template.apply"], "Apply")
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

        flow.step("Paste look › Every clip, then Change on its toast to correct the paste")
        flow.tool("pasteLook")
        let everyClip = app.buttons["edit.pasteLook.all"]
        XCTAssertTrue(flow.waits(for: everyClip, "Paste look"), "Paste look didn't ask where")
        flow.tap(everyClip, "Every clip")
        XCTAssertTrue(flow.toastSays("Look pasted on every clip"), "No toast after pasting on every clip")
        // The toast stays 4 s and is drawn once, by the editor (the hosts under its cover leave it to it; a second one fails the
        // tap): Change is touched at once, since on a busy Mac each look at the screen takes up to a second (11/11/2026: three
        // looks for the hidden copies outlasted the toast).
        flow.tapNow(app.buttons["toast.secondaryAction"])
        XCTAssertTrue(flow.waits(for: everyClip, "Paste look"), "Change didn't open Paste look")
        flow.tap(everyClip, "Every clip")
        XCTAssertTrue(flow.toastSays("Look pasted on every clip"), "No toast after correcting the paste")
        XCTAssertTrue(app.buttons["toast.action"].exists, "The paste's toast has no Undo")
        XCTAssertTrue(everyClip.isGone(within: 5))
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
        // The toast comes once the sheet has gone (0.35 s) and stays 2 s: it's looked for first, before anything else spends
        // that time (waiting for the sheet to go took long enough, before, for the toast to be gone when it was looked for).
        XCTAssertTrue(flow.toastSays("Every clip already looks like this"), "No toast after pasting a look that changes nothing")
        XCTAssertTrue(everyClip.isGone(within: 5))
        // Nothing changed: no undo step, the edit still unchanged.
        XCTAssertTrue(app.buttons["edit.toolbar.pasteLook"].exists(within: 5))
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
        XCTAssertTrue(preview.exists(within: 5))

        flow.step("Format")
        flow.tool("format")
        XCTAssertTrue(flow.waits(for: app.staticTexts["Aspect ratio"], "the Aspect ratio panel"), "Aspect ratio didn't open its panel")
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

    // MARK: - 6. React in a window

    /// The video reacted to plays in a window over the creator (the demo's B-roll, 4.2–8 s): picked on the preview, the back
    /// button says a video is picked, and its panel has the window, its size and its sound; ✓ keeps it picked.
    func testReactVideoInAWindowIsPickedAndAdjusted() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("react-window", app: app)

        flow.step("Scrub into the window and pick it on the preview")
        flow.scrub()
        flow.tap(app.buttons["edit.mediaHandle"], "the video in a window")
        let back = app.buttons["edit.toolbar.back"]
        XCTAssertTrue(flow.waits(for: back, "the video's tools"))
        XCTAssertEqual(back.value as? String, "Video", "The back button doesn't say a video is picked")

        flow.step("Its panel: window, size, sound")
        flow.tool("editMedia")
        XCTAssertTrue(flow.waits(for: app.buttons["edit.mediaLayout.window"], "the Media panel"))
        XCTAssertTrue(app.buttons["edit.mediaLayout.window"].isSelected, "The react video isn't in a window")
        XCTAssertTrue(flow.element("edit.mediaSize").exists, "No size for the window")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Media")
        XCTAssertEqual(back.value as? String, "Video", "✓ let go of the picked video")
        flow.backToMainTools()
        flow.report()
    }

    // MARK: - 7. Ad

    /// Another take joins the sequence where the sheet says before the tap (at the playhead), picked and named; the texts
    /// already there are styled together; the cover.
    func testAdCombinesTakesTextsAndTheCover() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("ad", app: app)

        flow.step("Media › In sequence › one of your takes")
        flow.tool("addMedia")
        flow.tool("mediaSequence")
        let note = flow.element("edit.mediaInsertionNote")
        XCTAssertTrue(flow.waits(for: note, "where the clip goes"))
        XCTAssertTrue(app.buttons["edit.mediaMode.sequence"].isSelected, "Media › In sequence didn't open on it")
        // The playhead is at the start: the take goes in before the first clip.
        XCTAssertEqual(note.label, "Goes in at 00:00.0, before clip 1", "The sheet doesn't say where the clip goes")
        let take = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'edit.addTake.'")).firstMatch
        flow.tap(take, "another take")
        XCTAssertTrue(flow.toastSays("added as clip 1, at 00:00.0", timeout: 10), "No word of where the take went")
        let back = app.buttons["edit.toolbar.back"]
        XCTAssertTrue(flow.waits(for: back, "the new clip's tools"), "The new clip isn't picked")
        XCTAssertEqual(back.value as? String, "Clip 1")
        flow.backToMainTools()

        flow.step("Text › Style all")
        flow.tool("text")
        flow.tool("styleAll")
        XCTAssertTrue(flow.waits(for: app.buttons["edit.panel.apply"], "Text style"), "Style all didn't open Text style")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Text style")
        flow.backToMainTools()

        flow.step("Cover")
        flow.tool("cover")
        let coverDone = app.buttons["cover.done"]
        XCTAssertTrue(flow.waits(for: coverDone, "Cover Studio"), "Cover didn't open Cover Studio")
        flow.tap(coverDone, "Cover Studio's Done")
        XCTAssertTrue(flow.isOnMainTools())
        flow.report()
    }

    // MARK: - 8. Coming back

    /// A mistake cut out, the editor left with ‹, opened again: the cut is there, the playhead and Undo still work on it.
    func testLeavingAndComingBackKeepsTheCutsAndUndo() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("coming-back", app: app)
        let full = EditorApp.length(app)

        flow.step("Cut a mistake: Edit › Split twice › Delete")
        flow.scrub(points: 120)
        flow.tool("edit")
        flow.tool("split")
        XCTAssertTrue(flow.toastSays("Split at"))
        // Slowly: a Simulator that loses the hold at the end glided the playhead onto the clip's last frames, where Split
        // rightly says "Move playhead onto the clip" (28/10/2026).
        flow.scrub(points: 90, velocity: 150)
        flow.tool("split")
        XCTAssertTrue(flow.toastSays("Split at"))
        let back = app.buttons["edit.toolbar.back"]
        XCTAssertTrue(flow.waits(for: back, "the clip's tools"))
        let picked = back.value as? String ?? ""
        flow.tool("delete")
        XCTAssertTrue(flow.toastSays("deleted"), "No toast after deleting \(picked)")
        let cut = EditorApp.length(app)
        XCTAssertNotEqual(cut, full, "Deleting the clip didn't shorten the video")

        flow.step("‹ out of the editor, Edit again")
        flow.tap(app.buttons["edit.backButton"], "‹ out of the editor")
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(flow.waits(for: edit, timeout: 10, "the review"), "‹ didn't leave the editor")
        flow.tap(edit, "Edit")
        EditorApp.waitUntilReady(app)
        XCTAssertEqual(EditorApp.length(app), cut, "The cut didn't come back with the draft")

        flow.step("Undo still knows the cut")
        flow.tap(app.buttons["edit.undoButton"], "Undo")
        XCTAssertEqual(EditorApp.length(app), full, "Undo after coming back didn't bring the clip back")
        flow.report()
    }

    // MARK: - 9. Captions in a format

    /// An edit from before formats shows none picked; Short phrase cuts the lines again (one Undo puts them back); a line's More
    /// breaks it where the cursor is (Return still goes on) and shows each word's time.
    func testCaptionsInAShortPhraseALineBreakAndWordTiming() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("caption-format", app: app)

        flow.step("Captions › Style › Format › Short phrase")
        flow.tool("captions")
        flow.tap(app.buttons["edit.captionsStyleButton"], "Aa Style")
        flow.tap(app.buttons["edit.panel.tab.format"], "Format")
        let phrase = app.buttons["edit.captionFormat.phrase"]
        XCTAssertTrue(flow.waits(for: phrase, "the formats"), "No Format in Caption style")
        XCTAssertFalse(phrase.isSelected, "An edit from before formats shows one picked")
        flow.tap(phrase, "Short phrase")
        // The preview shows the lines cut again: no toast (only VoiceOver hears it), and the player bar's Undo takes it back.
        XCTAssertTrue(phrase.isSelected)
        XCTAssertFalse(flow.toastSays("Captions format", timeout: 1), "A toast that only restates the preview")
        flow.capture("format-picked")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Caption style")

        flow.step("A line › More › Line break and Word timing")
        let line = flow.element("edit.captionLine.0")
        if !line.exists { flow.tap(app.buttons["edit.toolbar.captions"], "Captions") }
        flow.tap(flow.element("edit.captionLine.0"), "the first line")
        flow.tap(app.buttons["edit.captionMore"], "More")
        let breakChip = app.buttons["edit.captionBreak"]
        XCTAssertTrue(flow.waits(for: breakChip, "Line break"), "No Line break in More")
        XCTAssertTrue(flow.element("edit.captionWordTiming").exists, "No word timing in More")
        flow.capture("line-more")
        flow.tap(breakChip, "Line break")
        XCTAssertFalse(flow.toastSays("Line break added", timeout: 1), "A toast that only restates the preview")
        let field = app.descendants(matching: .any).matching(identifier: "edit.captionField").firstMatch
        XCTAssertTrue((field.value as? String)?.contains("\n") == true, "The line has no break: \(field.value ?? "")")
        flow.report()
    }

    // MARK: - 10. Every tool in reach

    /// The clip's speed and sound straight from the main bar, nothing picked first (✓ leaves nothing picked, and the bar, back
    /// where it was, scrolls to its start and stays there); then a hook's bar reaches the whole video's Adjust after its own
    /// tools, saying once that it changes the whole video, and its Clip goes to the clip under the playhead.
    func testTheMainBarAndAnItemsBarReachTheOtherTools() {
        let app = EditorApp.open(demo: true)
        let flow = CreatorWorkflow("tool-reach", app: app)
        XCTAssertFalse(app.buttons["edit.toolbar.delete"].exists, "The main bar offers Delete with nothing picked")

        flow.step("Speed on the main bar, nothing picked")
        flow.scrub()
        flow.tool("speed")
        let subtitle = app.staticTexts["edit.panel.subtitle"]
        XCTAssertTrue(flow.waits(for: subtitle, "Speed"), "Speed didn't open")
        XCTAssertTrue(subtitle.label.hasPrefix("Clip"), "Speed doesn't say which clip it changes: \(subtitle.label)")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Speed")
        XCTAssertTrue(flow.isOnMainTools(), "✓ on Speed left the clip picked")

        flow.step("Volume on the main bar")
        flow.tool("volume")
        XCTAssertTrue(flow.waits(for: subtitle, "Volume"), "Volume didn't open")
        XCTAssertTrue(subtitle.label.hasPrefix("Clip"), "Volume doesn't say which clip it changes: \(subtitle.label)")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Volume")
        XCTAssertTrue(flow.isOnMainTools(), "✓ on Volume left the clip picked")

        flow.step("Back to the bar's start: Edit")
        // The bar came back where Volume was; scrolled to its start, it stays there.
        flow.tool("edit")
        XCTAssertTrue(flow.waits(for: app.buttons["edit.toolbar.back"], "the clip's tools"), "Edit didn't pick the clip")
        flow.backToMainTools()

        flow.step("Text › Hook")
        flow.tool("text")
        flow.tool("hook")
        let hookField = app.textFields["edit.textField"]
        XCTAssertTrue(flow.waits(for: hookField, "the hook's field"))
        flow.tap(app.buttons["edit.panel.apply"], "✓ on the hook")
        XCTAssertTrue(flow.waits(for: app.buttons["edit.toolbar.editText"], "the text's tools"), "The new hook isn't picked after ✓")

        flow.step("The whole video's Adjust from the hook's bar")
        flow.tool("adjustVideo")
        XCTAssertTrue(flow.toastSays("Applies to the whole video"), "No word that Adjust reaches past the hook")
        XCTAssertTrue(flow.waits(for: subtitle, "Adjust"), "Adjust didn't open")
        XCTAssertTrue(subtitle.label.hasPrefix("Whole video"), "Adjust doesn't say it's the whole video's: \(subtitle.label)")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Adjust")
        XCTAssertTrue(flow.waits(for: app.buttons["edit.toolbar.editText"], "the text's tools"), "✓ on Adjust let go of the hook")

        flow.step("Adjust again: said once is enough")
        let notice = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Applies to the whole video")).firstMatch
        XCTAssertTrue(notice.isGone(within: 6), "The first notice stays")
        flow.tool("adjustVideo")
        XCTAssertFalse(notice.exists(within: 1.5), "Adjust said again that it reaches the whole video")
        flow.tap(app.buttons["edit.panel.apply"], "✓ on Adjust")

        flow.step("Clip, from the hook's bar")
        flow.tool("clipTools")
        let back = app.buttons["edit.toolbar.back"]
        XCTAssertTrue(flow.waits(for: app.buttons["edit.toolbar.speed"], "the clip's tools"), "Clip didn't open the clip's tools")
        XCTAssertTrue((back.value as? String)?.hasPrefix("Clip") == true, "The back button doesn't name the clip: \(back.value ?? "")")
        flow.backToMainTools()
        flow.report()
    }
}
