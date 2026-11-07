//
//  EditorUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The editor (Quick edit) from a take's review, on a small real video: the toolbar by context, a
/// panel's ✓, full screen, splitting and deleting a clip, undo and Done.
@MainActor
final class EditorUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheEditorOpensWithTheMainTools() {
        let app = EditorApp.open()
        XCTAssertTrue(app.buttons["edit.doneButton"].exists)
        XCTAssertTrue(app.buttons["edit.backButton"].exists)
        XCTAssertFalse(app.buttons["edit.exportButton"].exists)
        XCTAssertTrue(app.buttons["edit.playButton"].exists)
        // The owner's order (2026-10-16; Clean up where ✦ Smart was, 07/11): Edit, Captions, Text, Clean up, Media, Audio, Format,
        // Filters, Cover; Adjust and
        // Background are Edit's clip tools, and the old Crop and Overlay are gone (Format and Media replace them).
        for tool in ["edit", "captions", "text", "pauses", "addMedia", "audio", "format", "filters", "cover"] {
            XCTAssertTrue(app.buttons["edit.toolbar.\(tool)"].exists, tool)
        }
        for tool in ["adjust", "crop", "background", "media"] {
            XCTAssertFalse(app.buttons["edit.toolbar.\(tool)"].exists, tool)
        }
        XCTAssertFalse(app.buttons["edit.toolbar.back"].exists)
    }

    func testEditShowsTheClipsToolsAndBackReturns() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "edit")
        XCTAssertTrue(app.buttons["edit.toolbar.split"].exists(within: 5))
        XCTAssertTrue(app.buttons["edit.toolbar.speed"].exists)
        XCTAssertTrue(app.buttons["edit.toolbar.zoom"].exists)
        EditorApp.tapTool(app, "back")
        XCTAssertTrue(app.buttons["edit.toolbar.pauses"].exists(within: 5))
    }

    func testAdjustPicksASettingAndMovesItsRuler() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "adjust")
        let warmth = app.buttons["edit.adjust.warmth"]
        XCTAssertTrue(warmth.exists(within: 5))
        warmth.tap()
        XCTAssertTrue(warmth.isSelected)
        // The ruler is one adjustable element (not a system slider): a touch sets the value under it.
        let ruler = app.descendants(matching: .any)["edit.adjust.ruler"]
        XCTAssertTrue(ruler.exists(within: 5))
        XCTAssertEqual(ruler.label, "Warmth")
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.5)).tap()
        XCTAssertNotEqual(warmth.value as? String, "0")
        // Off zero: the dial says so and its own Reset shows.
        XCTAssertTrue(app.buttons["edit.adjust.resetOne"].exists(within: 5))
        app.buttons["edit.adjust.resetOne"].tap()
        XCTAssertFalse(app.buttons["edit.adjust.resetOne"].exists)
    }

    /// Skin is a panel of its own: opening it applies nothing; Natural sets every control at once; moving one makes it Custom; Texture
    /// waits for the smoothing; each control has its own Reset and the panel's Reset turns everything off. Adjust has no smoothing.
    func testSkinIsItsOwnPanelWithPresetsControlsAndReset() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "skinVideo")
        let smooth = app.buttons["edit.skin.smoothing"]
        XCTAssertTrue(smooth.exists(within: 5))
        XCTAssertEqual(smooth.label, "Smooth")
        XCTAssertEqual(smooth.value as? String, "0", "opening Skin applies nothing")
        let state = app.descendants(matching: .any)["edit.skin.state"]
        XCTAssertEqual(state.label, "Off")
        // Texture waits for the smoothing, in the ruler's room.
        app.buttons["edit.skin.texture"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.skin.textureNote"].exists(within: 5))
        XCTAssertFalse(app.descendants(matching: .any)["edit.skin.ruler"].exists)
        // Natural: every control at once.
        app.buttons["edit.skin.preset.natural"].tap()
        XCTAssertNotEqual(smooth.value as? String, "0")
        XCTAssertNotEqual(app.buttons["edit.skin.faceLight"].value as? String, "0")
        XCTAssertTrue(app.buttons["edit.skin.preset.natural"].isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["edit.skin.ruler"].exists(within: 5), "Refine has its ruler now")
        // A control moved: Custom.
        smooth.tap()
        let ruler = app.descendants(matching: .any)["edit.skin.ruler"]
        XCTAssertEqual(ruler.label, "Smooth")
        ruler.coordinate(withNormalizedOffset: CGVector(dx: 0.95, dy: 0.5)).tap()
        XCTAssertEqual(state.label, "Custom")
        XCTAssertFalse(app.buttons["edit.skin.preset.natural"].isSelected)
        // Its own Reset, then the panel's.
        app.buttons["edit.skin.resetOne"].tap()
        XCTAssertEqual(smooth.value as? String, "0")
        let reset = app.buttons["edit.panel.reset"]
        XCTAssertTrue(reset.exists(within: 5))
        reset.tap()
        XCTAssertEqual(app.buttons["edit.skin.faceLight"].value as? String, "0")
        XCTAssertEqual(state.label, "Off")
        // Adjust has no smoothing of its own any more.
        app.buttons["edit.panel.apply"].tap()
        EditorApp.tapTool(app, "adjustVideo")
        XCTAssertTrue(app.buttons["edit.adjust.exposure"].exists(within: 5))
        XCTAssertFalse(app.buttons["edit.adjust.skinSmoothing"].exists)
    }

    /// The owner's take (29/10/2026): the whole video in Studio, a clip picked. Skin's Reset is there for the Studio the clip shows,
    /// stays through Natural and Studio, and turns the clip's Skin off; so does Reset clip, and the whole video keeps its Studio.
    func testSkinResetTurnsAClipsSkinOffThoughTheWholeVideoHasStudio() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "skinVideo")
        let reset = app.buttons["edit.panel.reset"]
        let state = app.descendants(matching: .any)["edit.skin.state"]
        app.buttons["edit.skin.preset.natural"].tap()
        XCTAssertTrue(reset.exists(within: 3))
        app.buttons["edit.skin.preset.studio"].tap()
        XCTAssertTrue(reset.exists(within: 3), "Reset went with Studio on the whole video")
        app.buttons["edit.panel.apply"].tap()
        EditorApp.goToCaption(app, 2)
        EditorApp.mainTrack(app, at: 0.5).tap()
        EditorApp.tapTool(app, "skin")
        XCTAssertTrue(reset.exists(within: 3), "No Reset for the whole video's Studio on the clip")
        app.buttons["edit.skin.preset.natural"].tap()
        app.buttons["edit.skin.preset.studio"].tap()
        XCTAssertTrue(reset.exists(within: 3), "Reset went with Studio on the clip")
        reset.tap()
        XCTAssertEqual(state.label, "Off", "Reset left Skin on the clip")
        XCTAssertTrue(reset.isGone(within: 3), "Reset stayed with nothing left to reset")
        app.buttons["edit.skin.preset.studio"].tap()
        app.buttons["edit.panel.apply"].tap()
        EditorApp.tapTool(app, "resetClip")
        EditorApp.tapTool(app, "skin")
        XCTAssertEqual(state.label, "Off", "Reset clip left Skin on the clip")
        app.buttons["edit.panel.apply"].tap()
        app.buttons["edit.toolbar.back"].tap()
        EditorApp.tapTool(app, "skinVideo")
        XCTAssertTrue(app.buttons["edit.skin.preset.studio"].isSelected, "the whole video lost its Studio")
    }

    /// Swiping the video down takes it to full screen, as the player bar's button does, and up brings it back; the arrow at its
    /// foot does the same with a tap.
    func testSwipingTheVideoDownAndUpGoesToFullScreenAndBack() {
        let app = EditorApp.open(demo: true)
        let arrow = app.buttons["edit.preview.fullScreenArrow"]
        let exit = app.descendants(matching: .any)["edit.exitFullScreen"]
        XCTAssertTrue(arrow.exists(within: 5), "No arrow at the video's foot")
        XCTAssertEqual(arrow.label, "Full screen")
        // The preview's whole area: the video in the middle (nothing is laid on it at the start) and beside it.
        let preview = app.descendants(matching: .any)["edit.preview"].firstMatch
        func swipe(_ element: XCUIElement, x: CGFloat, from: CGFloat, to: CGFloat) {
            element.coordinate(withNormalizedOffset: CGVector(dx: x, dy: from))
                .press(forDuration: 0.05, thenDragTo: element.coordinate(withNormalizedOffset: CGVector(dx: x, dy: to)))
        }
        swipe(preview, x: 0.5, from: 0.2, to: 0.75)
        XCTAssertTrue(exit.exists(within: 5), "Swiping the video down didn't take it to full screen")
        XCTAssertEqual(arrow.label, "Exit full screen")
        swipe(exit, x: 0.05, from: 0.8, to: 0.3)
        XCTAssertTrue(exit.isGone(within: 5), "Swiping up didn't bring the editor back")
        swipe(preview, x: 0.06, from: 0.2, to: 0.75)
        XCTAssertTrue(exit.exists(within: 5), "Swiping down beside the video didn't take it to full screen")
        swipe(exit, x: 0.5, from: 0.7, to: 0.2)
        XCTAssertTrue(exit.isGone(within: 5), "Swiping the full screen video up didn't bring the editor back")
        arrow.tap()
        XCTAssertTrue(exit.exists(within: 5), "The arrow didn't take the video to full screen")
        arrow.tap()
        XCTAssertTrue(exit.isGone(within: 5), "The arrow didn't bring the editor back")
    }

    /// Natural, then Studio in Filters: Reset stays, on the whole video and on a clip, and on the clip takes off the whole video's
    /// filter too; so does Reset clip.
    func testFilterResetTakesAClipsFilterOffThoughTheWholeVideoHasOne() {
        let app = EditorApp.open(demo: true)
        let reset = app.buttons["edit.panel.reset"]
        EditorApp.tapTool(app, "filters")
        app.buttons["edit.filter.natural"].tap()
        XCTAssertTrue(reset.exists(within: 3), "No Reset with Natural on the whole video")
        app.buttons["edit.filter.studio"].tap()
        XCTAssertTrue(reset.exists(within: 3), "Reset went with Studio on the whole video")
        app.buttons["edit.panel.apply"].tap()
        EditorApp.goToCaption(app, 2)
        EditorApp.mainTrack(app, at: 0.5).tap()
        EditorApp.tapTool(app, "filters")
        XCTAssertTrue(reset.exists(within: 3), "No Reset for the whole video's Studio on the clip")
        app.buttons["edit.filter.natural"].tap()
        app.buttons["edit.filter.studio"].tap()
        XCTAssertTrue(reset.exists(within: 3), "Reset went with Studio on the clip")
        reset.tap()
        XCTAssertTrue(app.buttons["edit.filter.original"].isSelected, "Reset left a filter on the clip")
        app.buttons["edit.filter.studio"].tap()
        app.buttons["edit.panel.apply"].tap()
        EditorApp.tapTool(app, "resetClip")
        EditorApp.tapTool(app, "filters")
        XCTAssertTrue(app.buttons["edit.filter.original"].isSelected, "Reset clip left a filter on the clip")
    }

    /// Auto measures the real frames of the clip: it ends with a correction to dial down, or says the picture is
    /// already balanced; either way the picture is never left half-done.
    func testAutoMeasuresTheClipAndCompareShowsTheOriginal() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "adjust")
        let auto = app.buttons["edit.adjust.auto"]
        XCTAssertTrue(auto.exists(within: 5))
        auto.tap()
        // Measuring takes a moment; it ends with the intensity ruler, or a note when there's nothing to do.
        let amount = app.descendants(matching: .any)["edit.adjust.autoAmount"]
        var balanced = false
        var failed = false
        let deadline = Date().addingTimeInterval(20)
        while Date() < deadline, !amount.exists, !balanced, !failed {
            balanced = EditorApp.toastSays(app, "Already balanced", timeout: 0.5)
            failed = EditorApp.toastSays(app, "Couldn’t measure", timeout: 0.5)
        }
        if amount.exists {
            // Intensity is its own ruler; Compare shows the picture as recorded, and Reset takes Auto away.
            let compare = app.buttons["edit.compare.picture"]
            XCTAssertTrue(compare.exists)
            // ◐ held shows the original only while pressed; a tap keeps it until the next tap, with "Original" on the preview.
            compare.press(forDuration: 0.5)
            XCTAssertFalse(compare.isSelected)
            compare.tap()
            XCTAssertTrue(compare.isSelected)
            XCTAssertTrue(app.descendants(matching: .any)["edit.originalPictureBadge"].exists(within: 3))
            compare.tap()
            XCTAssertFalse(compare.isSelected)
            XCTAssertTrue(app.buttons["edit.adjust.resetOne"].exists(within: 5))
            app.buttons["edit.adjust.resetOne"].tap()
            XCTAssertFalse(amount.exists)
        } else {
            XCTAssertTrue(balanced || failed)
        }
        XCTAssertTrue(auto.isEnabled)
    }

    func testFiltersOfferTheCollectionAndStartAtTheirOwnIntensity() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "filters")
        for id in ["original", "natural", "studio", "soft", "cinema", "warmEditorial", "retro", "monoSoft", "monoContrast"] {
            XCTAssertTrue(app.buttons["edit.filter.\(id)"].exists(within: 5), id)
        }
        // The first filters only show while one of them is picked.
        XCTAssertFalse(app.buttons["edit.filter.vivid"].exists)
        let cinema = app.buttons["edit.filter.cinema"]
        cinema.tap()
        XCTAssertTrue(cinema.isSelected)
        XCTAssertTrue(app.descendants(matching: .any)["edit.filter.intensity"].exists(within: 5))
    }

    /// The filters past the screen's edge are a drag away, for the whole video and for one clip of a montage: the row stays
    /// where the thumb leaves it.
    func testTheFilterRowStaysWhereItIsDragged() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "filters")
        XCTAssertTrue(dragsTheRowToItsEnd(app), "The whole video's filters slid back")
        app.buttons["edit.panel.apply"].tap()
        EditorApp.scrub(app)
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "split")
        EditorApp.tapTool(app, "filters")
        XCTAssertTrue(app.staticTexts["edit.panel.subtitle"].label.hasPrefix("Clip 2 of 2"))
        XCTAssertTrue(dragsTheRowToItsEnd(app), "A clip's filters slid back")
    }

    /// Drags the filter row from its middle, twice, then waits: B&W Film, the last filter, is whole on screen and stays there,
    /// with Original past the leading edge. (XCUITest calls the cards not hittable after the drag while a finger's tap picks
    /// them: the frames, not `isHittable`, say where the row is.)
    private func dragsTheRowToItsEnd(_ app: XCUIApplication) -> Bool {
        let last = app.buttons["edit.filter.filmMono"]
        let natural = app.buttons["edit.filter.natural"]
        guard natural.exists(within: 5) else { return false }
        for _ in 0..<2 {
            let start = app.coordinate(withNormalizedOffset: .zero).withOffset(CGVector(dx: 330, dy: natural.frame.midY))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: -280, dy: 0)), withVelocity: 500, thenHoldForDuration: 0.3)
        }
        Thread.sleep(forTimeInterval: 2)
        return app.windows.firstMatch.frame.contains(last.frame) && app.buttons["edit.filter.original"].frame.maxX < 0
    }

    /// The ruler is the panel's lowest control: it stays above the bottom safe area (the Home
    /// Indicator's strip) and the clearance the panel keeps under its controls, on any iPhone.
    func testAdjustRulerStaysAboveTheBottomEdge() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "adjust")
        let ruler = app.descendants(matching: .any)["edit.adjust.ruler"]
        XCTAssertTrue(ruler.exists(within: 5))
        let window = app.windows.firstMatch.frame
        XCTAssertLessThanOrEqual(ruler.frame.maxY, window.maxY - 20)
        XCTAssertTrue(ruler.isHittable)
    }

    /// Play plays and pause stops. On a device the playhead moves through the take while it plays; the Simulator can't draw the editor's
    /// composition (the item fails with -12784 before it is ready, as `QuickEditPlayerTests` notes), so there only the state is checked.
    func testPlayPlaysAndPauseHoldsThePlayhead() {
        let app = EditorApp.open()
        let play = app.buttons["edit.playButton"]
        XCTAssertTrue(play.exists(within: 5))
        XCTAssertEqual(play.label, "Play")
        let time = app.staticTexts["edit.timeLabel"]
        let start = time.value as? String ?? time.label
        play.tap()
        XCTAssertEqual(play.label, "Pause")
        #if !targetEnvironment(simulator)
        XCTAssertTrue(time.matches(NSPredicate(format: "value != %@", start), within: 8), "the playhead didn't move")
        #endif
        play.tap()
        XCTAssertEqual(play.label, "Play")
        let held = time.value as? String
        sleep(1)
        XCTAssertEqual(time.value as? String, held, "pause didn't hold the playhead")
    }

    /// Edit by text › "Fix caption text": the caption line of the picked words opens with the keyboard up, ready to type.
    func testFixCaptionTextOpensTheLineReadyToType() {
        // The demo's words were heard already: the Simulator can't recognize speech.
        let app = EditorApp.open(demo: true, arguments: ["-uiTestDemoTranscript"])
        EditorApp.tapTool(app, "editByText")
        let first = app.buttons["edit.transcript.word.2"]
        XCTAssertTrue(first.exists(within: 5), "No words in Edit by text")
        first.tap()
        app.buttons["edit.transcript.word.3"].tap()
        let fix = app.buttons["edit.transcript.fix"]
        XCTAssertTrue(fix.exists(within: 5), "No Fix caption text")
        fix.tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.panel.captions"].exists(within: 5), "Fix caption text didn't open Captions")
        XCTAssertTrue(app.keyboards.firstMatch.exists(within: 5), "Fix caption text left the line closed")
    }

    func testFullScreenShowsOnlyTheVideoAndComesBack() {
        let app = EditorApp.open()
        app.buttons["edit.fullScreenButton"].tap()
        let exit = app.descendants(matching: .any)["edit.exitFullScreen"]
        XCTAssertTrue(exit.exists(within: 5))
        exit.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.5)).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].exists(within: 5))
    }

    func testSplittingDeletingUndoingAndSavingAClip() {
        let app = EditorApp.open()
        XCTAssertTrue(EditorApp.length(app).hasPrefix("01:02.0"))
        EditorApp.tapTool(app, "edit")
        // At the very start the playhead can't split: a toast says why.
        EditorApp.tapTool(app, "split")
        XCTAssertTrue(app.staticTexts["Move playhead onto the clip"].exists(within: 5))
        EditorApp.tapTool(app, "back")

        EditorApp.scrub(app)
        EditorApp.tapTool(app, "edit")
        EditorApp.tapTool(app, "split")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Split at'")).firstMatch.exists(within: 5))
        EditorApp.tapTool(app, "delete")
        XCTAssertFalse(EditorApp.length(app).hasPrefix("01:02.0"))
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(EditorApp.length(app).hasPrefix("01:02.0"))
        app.buttons["edit.redoButton"].tap()
        XCTAssertFalse(EditorApp.length(app).hasPrefix("01:02.0"))

        EditorApp.done(app)
        XCTAssertTrue(app.buttons["review.editButton"].exists(within: 5))
    }

    /// The largest text size: the video, the timeline and the tools stay; a panel replaces the toolbar until its ✓, and scrolls.
    func testTheLargestTextKeepsTheVideoAndTheTools() {
        let app = EditorApp.open(arguments: ["-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityXXXL"])
        XCTAssertTrue(app.descendants(matching: .any)["edit.preview"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["edit.timeline"].exists)
        EditorApp.tapTool(app, "adjust")
        let apply = app.buttons["edit.panel.apply"]
        XCTAssertTrue(apply.exists(within: 5))
        XCTAssertTrue(apply.isHittable)
        XCTAssertFalse(app.buttons["edit.toolbar.adjust"].exists, "The panel replaces the toolbar until its ✓")
        XCTAssertTrue(app.descendants(matching: .any)["edit.preview"].frame.height >= 150)
        apply.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.adjust"].exists(within: 5))
    }

    /// Done always asks "Is it ready to post?", with four answers; swiping the sheet down goes back.
    func testDoneAsksIfItIsReadyToPost() {
        let app = EditorApp.open()
        app.buttons["edit.doneButton"].tap()
        XCTAssertTrue(app.buttons["edit.done.share"].exists(within: 5))
        for answer in ["download", "ready", "notYet"] {
            XCTAssertTrue(app.buttons["edit.done.\(answer)"].exists, answer)
        }
        // Back to the editor: the sheet swipes down and the tools are still there.
        app.descendants(matching: .any)["edit.doneSheet"].firstMatch.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["edit.done.share"].isGone(within: 5))
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].exists(within: 5))
    }

    /// D11: under Done's answers, a quiet line opens the same Export options Share and Download use, with the quality the file is made in.
    func testDoneReachesTheExportOptions() {
        let app = EditorApp.open()
        app.buttons["edit.doneButton"].tap()
        let line = app.buttons["edit.done.exportOptions"]
        XCTAssertTrue(line.exists(within: 5))
        XCTAssertTrue(line.label.contains("1080p"))
        line.tap()
        XCTAssertTrue(app.switches["share.captionsToggle"].exists(within: 5))
        XCTAssertTrue(app.descendants(matching: .any)["share.qualityRecorded"].firstMatch.exists)
    }

    /// With the last free export left, Done says so under its question (owner, 06/11/2026); with more left it says nothing.
    func testDoneSaysWhenItIsTheLastFreeExport() {
        let app = EditorApp.open(arguments: ["-uiTestExportsLeft", "1"])
        app.buttons["edit.doneButton"].tap()
        let note = app.descendants(matching: .any)["edit.done.exportNote"].firstMatch
        XCTAssertTrue(note.exists(within: 5))
        XCTAssertEqual(note.label, "LAST FREE EXPORT")
        XCTAssertTrue(app.buttons["edit.done.download"].exists)
        app.terminate()

        let spare = EditorApp.open(arguments: ["-uiTestExportsLeft", "2"])
        spare.buttons["edit.doneButton"].tap()
        XCTAssertTrue(spare.buttons["edit.done.share"].exists(within: 5))
        XCTAssertFalse(spare.descendants(matching: .any)["edit.done.exportNote"].firstMatch.exists)
    }

    /// "Not yet, I'll come back" leaves the edit open: the review offers to continue it.
    func testNotYetKeepsTheEditOpenAndTheReviewSaysContinue() {
        let app = EditorApp.open()
        EditorApp.done(app, answer: "notYet")
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.exists(within: 5))
        let continues = NSPredicate(format: "label == 'Continue'")
        XCTAssertTrue(edit.matches(continues, within: 8), edit.label)
        // And the stage bar says so: the video is in edit.
        XCTAssertTrue(app.descendants(matching: .any)["review.stageBar"].exists)
    }

    /// Back asks nothing and keeps the draft.
    func testBackLeavesWithoutAskingAndKeepsTheDraft() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "edit")
        EditorApp.scrub(app)
        EditorApp.tapTool(app, "split")
        app.buttons["edit.backButton"].tap()
        XCTAssertFalse(app.buttons["edit.done.share"].exists)
        XCTAssertTrue(app.buttons["review.editButton"].exists(within: 5))
    }

    /// Done › "Yes — share": the edited video is made and "Ready to travel" opens over the review (it used to close the app).
    func testSharingRightAfterEditingOpensReadyToTravel() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "edit")
        EditorApp.scrub(app)
        EditorApp.tapTool(app, "split")
        EditorApp.done(app, answer: "share")
        XCTAssertTrue(app.descendants(matching: .any)["ready.sheet"].exists(within: 30), "Ready to travel never opened")
        XCTAssertEqual(app.state, .runningForeground)
    }

    /// Edited, back in the review: its Share makes the edited video and "Ready to travel" opens.
    func testTheReviewsShareAfterAnEditOpensReadyToTravel() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "edit")
        EditorApp.scrub(app)
        EditorApp.tapTool(app, "split")
        EditorApp.done(app)
        let share = app.buttons["review.shareButton"]
        XCTAssertTrue(share.exists(within: 10))
        share.tap()
        XCTAssertTrue(app.descendants(matching: .any)["ready.sheet"].exists(within: 30), "Ready to travel never opened")
        XCTAssertEqual(app.state, .runningForeground)
    }

    // MARK: - Voice-over

    /// Audio › Voice-over on a take with a script offers "Show script" (on): the script shows over the preview with the
    /// teleprompter's speed under the switch; turning it off takes both away. Recording isn't run (no microphone in the Simulator).
    func testVoiceOverShowsTheScriptOverThePreviewUntilItsSwitchIsOff() {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "audio")
        let voiceOver = app.buttons["edit.toolbar.voiceOver"]
        XCTAssertTrue(voiceOver.exists(within: 5))
        voiceOver.tap()
        let toggle = app.descendants(matching: .any)["edit.voiceOverScriptToggle"]
        XCTAssertTrue(toggle.exists(within: 5), "No Show script in Voice-over")
        XCTAssertEqual(toggle.value as? String, "On")
        let script = app.descendants(matching: .any)["edit.narrationScript"]
        XCTAssertTrue(script.exists(within: 5), "The script isn't over the preview")
        XCTAssertTrue(app.descendants(matching: .any)["prompter.speedSlider"].exists)
        XCTAssertTrue(app.buttons["edit.recordVoiceOverButton"].exists)
        toggle.tap()
        XCTAssertTrue(script.isGone(within: 5), "The script stayed after Show script was turned off")
        XCTAssertEqual(toggle.value as? String, "Off")
        XCTAssertFalse(app.descendants(matching: .any)["prompter.speedSlider"].exists)
    }

    // MARK: - Timeline

    /// Templates opens on its tab, apart from the brand kits; a template applies to the whole video, is marked as the one in use
    /// and comes off with one Undo.
    func testTemplatesOpenOnTheirTabApartFromBrandKits() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "brandKit")
        XCTAssertTrue(app.buttons["edit.brand.newKit"].exists(within: 5))
        XCTAssertFalse(app.buttons["edit.template.boldHook"].exists)
        app.buttons["edit.templates.section.templates"].tap()
        let boldHook = app.buttons["edit.template.boldHook"]
        XCTAssertTrue(boldHook.exists(within: 5))
        XCTAssertFalse(app.buttons["edit.brand.newKit"].exists)
        boldHook.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Bold hook on the whole video"))
        XCTAssertTrue(boldHook.isSelected)
        app.buttons["edit.undoButton"].tap()
        XCTAssertFalse(boldHook.isSelected)
    }

    func testDraggingTheTimelineScrubsThePlayhead() {
        let app = EditorApp.open()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertEqual(time.value as? String, "00:00.0 / 01:02.0")
        EditorApp.scrub(app)
        XCTAssertNotEqual(time.value as? String, "00:00.0 / 01:02.0")
        XCTAssertTrue((time.value as? String)?.hasSuffix("/ 01:02.0") ?? false)
    }

    /// A finger that rests before moving (longer than a hold on a clip takes) still scrubs anywhere but on a clip.
    func testAFingerThatRestsBeforeMovingStillScrubs() {
        let app = EditorApp.open()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertEqual(time.value as? String, "00:00.0 / 01:02.0")
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        // The ruler, then the empty space under the tracks.
        for (place, dy) in [("the ruler", 0.06), ("under the tracks", 0.97)] {
            let before = time.value as? String
            let start = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: dy))
            start.press(forDuration: 0.8, thenDragTo: start.withOffset(CGVector(dx: -150, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.3)
            XCTAssertNotEqual(time.value as? String, before, "A drag after a rest on \(place) didn't move the playhead")
        }
        XCTAssertFalse(app.descendants(matching: .any)["edit.reorder.list"].exists, "A rest off a clip opened Reorder")
        // On the clip a rest is a hold, for Reorder (one clip here: it says how to get a second).
        EditorApp.mainTrack(app, at: 0.5).press(forDuration: 0.8)
        XCTAssertTrue(EditorApp.toastSays(app, "Split or add a clip to reorder"), "A hold on the clip did nothing")
    }

    /// A slow drag from where the playhead snapped (the start of the video) takes it along: the snap holds it only while the
    /// finger is within reach, not for every step shorter than that reach.
    func testASlowDragLeavesWhereThePlayheadSnapped() {
        let app = EditorApp.open()
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertEqual(time.value as? String, "00:00.0 / 01:02.0")
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        let start = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.06))
        // 176 pt at 44 pt a second: 4 s, at 2 points a frame.
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -176, dy: 0)), withVelocity: 120, thenHoldForDuration: 0.3)
        let label = time.value as? String ?? ""
        let seconds = Double(label.prefix(7).dropFirst(3)) ?? 0
        XCTAssertGreaterThan(seconds, 2, "A slow drag stayed where the playhead snapped: \(label)")
    }

    func testTappingTheVideoTrackPicksTheClipAndEmptySpaceLetsGo() {
        let app = EditorApp.open()
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        EditorApp.mainTrack(app, at: 0.75).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.split"].exists(within: 5))
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.75, dy: 0.97)).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.pauses"].exists(within: 5))
    }

    func testTheClipsLeftHandleTrimsItsStart() {
        let app = EditorApp.open()
        EditorApp.mainTrack(app, at: 0.75).tap()
        XCTAssertTrue(app.buttons["edit.toolbar.split"].exists(within: 5))
        // With the playhead at the start, the clip's left handle sits just left of the middle.
        let handle = EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: -7, dy: 0))
        handle.press(forDuration: 0.2, thenDragTo: handle.withOffset(CGVector(dx: 88, dy: 0)), withVelocity: 300, thenHoldForDuration: 0.3)
        XCTAssertFalse(EditorApp.length(app).hasPrefix("01:02.0"))
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(EditorApp.length(app).hasPrefix("01:02.0"))
    }

    // MARK: - Layout (owner's order, 2026-10-16)

    /// Reorder, from the clip's tools once there are two clips: the clips in a list to drag.
    func testReorderFromTheClipToolsOpensTheListOfClips() {
        let app = EditorApp.open()
        EditorApp.tapTool(app, "edit")
        EditorApp.scrub(app)
        EditorApp.tapTool(app, "split")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Split at'")).firstMatch.exists(within: 5))
        EditorApp.tapTool(app, "reorder")
        XCTAssertTrue(app.descendants(matching: .any)["edit.reorder.list"].exists(within: 5))
        XCTAssertTrue(app.descendants(matching: .any)["edit.reorder.clip.0"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["edit.reorder.clip.1"].exists)
    }

    // MARK: - Low Power Mode

    /// With Low Power Mode on, the editor says so at the foot of the preview, without stopping anything; ✕ lets it go.
    func testLowPowerModeIsSaidOverThePreviewUntilClosed() {
        let app = EditorApp.open(arguments: ["-uiTestLowPower"])
        let notice = app.descendants(matching: .any)["edit.lowPowerNotice"]
        XCTAssertTrue(notice.exists(within: 5))
        XCTAssertTrue(notice.label.contains("Low Power Mode is on"), notice.label)
        // The edit goes on under it.
        XCTAssertTrue(app.buttons["edit.playButton"].isHittable)
        let close = app.buttons["edit.lowPowerNotice.close"]
        XCTAssertGreaterThanOrEqual(close.frame.width, 44)
        close.tap()
        XCTAssertTrue(notice.isGone(within: 3))
    }

    /// Xcode's accessibility audit on the editor and an open panel. Text sizes aren't audited: the editor's are capped on purpose
    /// (panels grow to AX Medium and then scroll; the toolbar's fixed labels show large on a long press, `DESIGN_PROJECT` §44). The
    /// toolbar's last tool fades under its edge on purpose, to show the bar scrolls on: its contrast isn't counted there.
    func testTheEditorPassesTheAccessibilityAudit() throws {
        let app = EditorApp.open()
        let screen = app.windows.firstMatch.frame
        var found: [String] = []
        let audit: (XCUIAccessibilityAuditIssue) -> Bool = { issue in
            if issue.auditType == .contrast, let element = issue.element, element.frame.maxX > screen.maxX - 64,
               app.descendants(matching: .any)["edit.toolbar"].frame.intersects(element.frame) {
                return true
            }
            found.append("\(issue.compactDescription) · \(issue.element?.identifier ?? "") · \(issue.element?.label ?? "")")
            return true
        }
        let types: XCUIAccessibilityAuditType = .all.subtracting(.dynamicType)
        try app.performAccessibilityAudit(for: types, audit)
        EditorApp.tapTool(app, "adjustVideo")
        try app.performAccessibilityAudit(for: types, audit)
        XCTAssertTrue(found.isEmpty, found.joined(separator: "\n"))
    }

    /// Arabic chosen in Cue on an iPhone in English: the editor and its panels lay out right to left (the window's trait,
    /// `InterfaceDirection`), while the frame steps keep time left to right.
    func testArabicLaysTheEditorOutRightToLeft() {
        let app = EditorApp.open(arguments: ["-uiTestAppLanguage", "ar"])
        EditorApp.tapTool(app, "edit")
        let speed = app.buttons["edit.toolbar.speed"]
        XCTAssertTrue(speed.exists(within: 5))
        speed.tap()
        let apply = app.buttons["edit.panel.apply"]
        let title = app.staticTexts["edit.panel.subtitle"]
        XCTAssertTrue(apply.exists(within: 5))
        XCTAssertTrue(title.exists(within: 2))
        XCTAssertLessThan(apply.frame.midX, title.frame.midX, "The panel’s ✓ is on the left in Arabic")
        let back = app.buttons["edit.previousFrame"], forward = app.buttons["edit.nextFrame"]
        if back.exists, forward.exists { XCTAssertLessThan(back.frame.midX, forward.frame.midX, "Time runs left to right") }
    }
}
