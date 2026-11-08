//
//  RealTakeEditorTrustUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Stage 5 of the editor plan on a COPY of one of the creator's own takes, in memory (`-uiTestRealTake`): the take is never changed
/// and nothing goes to Photos. What the Simulator can't prove, because it doesn't hear speech nor run Vision on a real face: Auto edit
/// listening to the real voice, Quick pass, the cut-out person blurred, moved, resized and checked frame by frame, and Punch in on
/// the cuts that the clean-up made. Each step prints what the editor said (`CREATOR STEP …`) and attaches a picture to the result.
/// Opt-in on an iPhone:
/// `CUE_DEVICE=… TEST_RUNNER_CUE_REAL_TAKE=<file name in Takes> scripts/test.sh device-ui RealTakeEditorTrustUITests`
/// (`TEST_RUNNER_CUE_REAL_TAKE_UNSCRIPTED=1` for a take recorded without a script).
@MainActor
final class RealTakeEditorTrustUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Auto edit on the real speech: the captions it makes, the cuts, Before | After, one step turned off, and one Undo for the run.
    func testAutoEditListensToTheRealSpeechAndEachStepTurnsOff() throws {
        let app = try openTake()
        let full = EditorApp.length(app)
        EditorApp.tapTool(app, "autoEdit")
        let captions = app.switches["edit.autoEdit.captions"]
        XCTAssertTrue(captions.exists(within: 5), "Auto edit didn't open")
        for step in ["zoom", "punchIn"] {
            let toggle = app.switches["edit.autoEdit.\(step)"]
            // Only a switch in sight: one under the pinned Auto edit button would take the tap and start the run.
            for _ in 0..<3 where toggle.exists && !toggle.isHittable { app.swipeUp(velocity: .slow) }
            if toggle.isHittable, toggle.isEnabled, toggle.value as? String == "0" {
                toggle.switches.firstMatch.tap()
            }
            say("\(step) is \(toggle.value as? String ?? "?")")
        }
        attach(app, "auto-edit-choosing")
        let started = Date()
        let run = app.buttons["edit.autoEdit.run"]
        if run.exists { run.tap() }
        let speech = app.descendants(matching: .any)["edit.autoEdit.result.speech"]
        XCTAssertTrue(speech.exists(within: 240), "Auto edit didn't finish in 4 minutes on a real take")
        say("auto edit took \(Int(Date().timeIntervalSince(started))) s")
        for step in ["speech", "captions", "zoom", "punchIn"] {
            // The results are a list: a row under the fold is drawn once it scrolls in.
            let row = app.descendants(matching: .any)["edit.autoEdit.result.\(step)"]
            for _ in 0..<3 where !row.exists { app.swipeUp(velocity: .slow) }
            say("\(step): \(row.exists ? row.label : "no row")")
        }
        for _ in 0..<3 where !speech.isHittable { app.swipeDown(velocity: .slow) }
        attach(app, "auto-edit-results")
        let edited = EditorApp.length(app)
        say("length \(full) → \(edited)")
        XCTAssertFalse(speech.label.contains("Didn't run"), "The speech wasn't heard: \(speech.label)")

        let compare = app.segmentedControls["edit.autoEdit.compare"]
        if compare.buttons["Before"].isEnabled {
            compare.buttons["Before"].tap()
            XCTAssertTrue(speech.exists(within: 5), "The results went away on Before")
            attach(app, "auto-edit-before")
            compare.buttons["After"].tap()
        }
        let off = app.buttons["edit.autoEdit.off.speech"]
        if edited != full, off.exists(within: 3) {
            off.tap()
            XCTAssertTrue(speech.label.contains("Turned off"), speech.label)
            closeSheet(app)
            XCTAssertEqual(EditorApp.length(app), full, "Turning the clean-up off didn't bring every cut back")
            app.buttons["edit.undoButton"].tap()
            XCTAssertEqual(EditorApp.length(app), edited, "Undo didn't take the turning off back")
        } else {
            closeSheet(app)
        }
        app.buttons["edit.undoButton"].tap()
        XCTAssertEqual(EditorApp.length(app), full, "One Undo didn't take the whole run back")
        attach(app, "auto-edit-undone")
    }

    /// Clean up › Quick pass on the real speech: what it marks, Remove, and Undo.
    func testQuickPassMarksTheRealSpeechAndRemoveTakesItOut() throws {
        let app = try openTake()
        let full = EditorApp.length(app)
        EditorApp.openPauses(app)
        let quick = app.buttons["edit.pauses.quickPass"]
        // Quick pass waits for Clean up to listen: the pauses' list (or "no pauses") says it is done.
        let listened = app.buttons["edit.pauses.apply"].exists(within: 120)
            || app.descendants(matching: .any)["edit.pauses.empty"].exists
        XCTAssertTrue(listened && quick.exists, "Clean up didn't finish listening in 2 minutes")
        guard quick.isEnabled else {
            say("Quick pass is off: nothing clear to take out")
            attach(app, "quick-pass-nothing")
            return
        }
        quick.tap()
        let toast = app.descendants(matching: .any).matching(identifier: "toast").firstMatch
        if toast.exists(within: 5) { say("Quick pass said: \(toast.label)") }
        attach(app, "quick-pass-marked")
        let apply = app.buttons["edit.pauses.apply"]
        XCTAssertTrue(apply.exists(within: 5), "No Remove after Quick pass")
        say("Remove says: \(apply.label)")
        apply.tap()
        let after = EditorApp.length(app)
        say("length \(full) → \(after)")
        XCTAssertNotEqual(after, full, "Remove took nothing out")
        attach(app, "quick-pass-removed")
        let apply2 = app.buttons["edit.panel.apply"]
        if apply2.exists(within: 2) { apply2.tap() }
        app.buttons["edit.undoButton"].tap()
        XCTAssertEqual(EditorApp.length(app), full, "Undo didn't bring the speech back")
    }

    /// Background › Blur on the real face, the person moved and resized, Check the cutout through the whole take, and back.
    func testTheCutOutPersonIsBlurredMovedAndCheckedOnTheRealTake() throws {
        let app = try openTake()
        EditorApp.tapTool(app, "backgroundVideo")
        let blur = app.buttons["edit.background.blur"]
        XCTAssertTrue(blur.exists(within: 5), "No Background panel")
        blur.tap()
        let place = app.descendants(matching: .any)["edit.personPlace"]
        let panel = app.scrollViews.firstMatch
        for _ in 0..<4 where !place.isHittable { panel.swipeUp(velocity: .slow) }
        XCTAssertTrue(place.exists(within: 5), "No Where you are with Blur on")
        attach(app, "cutout-blur")

        let layer = app.descendants(matching: .any)["edit.personPlaceLayer"]
        if layer.exists(within: 5) {
            let from = layer.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: -60, dy: 30)))
            let moved = app.staticTexts["Moved"]
            XCTAssertTrue(moved.exists(within: 3), "Dragging on the preview didn't move the person")
            layer.pinch(withScale: 0.75, velocity: -1)
            say("after the pinch: \(app.descendants(matching: .any)["edit.personSize"].value as? String ?? "?")")
            attach(app, "cutout-moved")
        } else {
            say("no outline on the preview (Vision found nobody yet)")
        }

        let check = app.buttons["edit.cutoutCheckButton"]
        for _ in 0..<4 where !check.isHittable { panel.swipeUp(velocity: .slow) }
        if check.exists(within: 3) {
            let started = Date()
            check.tap()
            let state = app.descendants(matching: .any)["edit.cutoutCheckState"]
            let done = NSPredicate(format: "label CONTAINS 'Found you' OR label CONTAINS 'lost you'")
            let finished = XCTNSPredicateExpectation(predicate: done, object: state)
            XCTAssertEqual(XCTWaiter().wait(for: [finished], timeout: 240), .completed, "Check the cutout didn't finish: \(state.label)")
            say("check the cutout (\(Int(Date().timeIntervalSince(started))) s): \(state.label)")
            attach(app, "cutout-checked")
            let miss = app.buttons["edit.cutoutMiss.0"]
            if miss.exists {
                miss.tap()
                say("the first miss took the playhead to \(EditorApp.length(app))")
            }
        } else {
            say("no Check the cutout")
        }
        let reset = app.buttons["edit.personReset"]
        for _ in 0..<4 where !reset.isHittable { panel.swipeUp(velocity: .slow) }
        if reset.exists, reset.isEnabled {
            reset.tap()
            XCTAssertTrue(app.staticTexts["As recorded"].exists(within: 3), "Back where you were recorded didn't bring the person back")
        }
        app.buttons["edit.panel.apply"].tap()
    }

    /// Clean up's pauses out, then a clip › Zoom › Punch in on cuts on the cuts they made: what the panel says, and Undo.
    func testPunchInOnTheCutsTheCleanUpMade() throws {
        let app = try openTake()
        EditorApp.openPauses(app)
        let apply = app.buttons["edit.pauses.apply"]
        let none = app.descendants(matching: .any)["edit.pauses.empty"]
        _ = apply.exists(within: 120) || none.exists
        guard apply.exists, apply.isEnabled else {
            say("no pauses to remove: Punch in needs a cut")
            return
        }
        apply.tap()
        let close = app.buttons["edit.panel.apply"]
        if close.exists(within: 2) { close.tap() }
        let back = app.buttons["edit.toolbar.back"]
        if back.exists(within: 2) { back.tap() }

        EditorApp.mainTrack(app, at: 0.15).tap()
        EditorApp.tapTool(app, "zoom")
        let cuts = app.descendants(matching: .any)["edit.zoom.cuts"]
        let panel = app.scrollViews.firstMatch
        for _ in 0..<4 where !cuts.isHittable { panel.swipeUp(velocity: .slow) }
        XCTAssertTrue(cuts.exists(within: 5), "No Punch in on cuts in Zoom")
        cuts.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Punch in on", timeout: 5), "No toast after Punch in on cuts")
        let closer = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'clips closer'")).firstMatch
        say("Punch in on cuts: \(cuts.value as? String ?? "?") · \(closer.label)")
        let limit = app.descendants(matching: .any)["edit.zoom.cutsLimit"]
        if limit.exists { say("limit: \(limit.label)") }
        attach(app, "punch-in")
        app.buttons["edit.panel.apply"].tap()
        app.buttons["edit.undoButton"].tap()
        EditorApp.mainTrack(app, at: 0.15).tap()
        EditorApp.tapTool(app, "zoom")
        for _ in 0..<4 where !cuts.isHittable { panel.swipeUp(velocity: .slow) }
        let on = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'clips closer'")).firstMatch
        say("after Undo: \(cuts.value as? String ?? "?")")
        XCTAssertFalse(on.exists, "Undo left Punch in on cuts on: \(on.label)")
    }

    // MARK: - Private

    private func openTake() throws -> XCUIApplication {
        guard let take = ProcessInfo.processInfo.environment["CUE_REAL_TAKE"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_REAL_TAKE to a take's file name on the iPhone (one with speech)")
        }
        let unscripted = ProcessInfo.processInfo.environment["CUE_REAL_TAKE_UNSCRIPTED"] != nil
        return EditorApp.open(arguments: ["-uiTestRealTake", take] + (unscripted ? ["-uiTestRealTakeUnscripted"] : []))
    }

    /// The sheet's ✕ (on the iPhone a swipe down can land on the results' list and leave the sheet open).
    private func closeSheet(_ app: XCUIApplication) {
        // The glass ✕ of `cueSheetChrome`: a system close button, found by its name.
        let close = app.buttons.matching(NSPredicate(format: "label == 'Close' OR identifier == 'Close'")).firstMatch
        if close.exists(within: 3) { close.tap() }
        XCTAssertTrue(app.descendants(matching: .any)["edit.autoEdit.compare"].isGone(within: 5), "Auto edit didn't close")
    }

    private func say(_ text: String) {
        print("CREATOR STEP real-take-trust · \(name) · \(text)")
    }

    /// The screen now, kept with the result on the Mac (nothing is written on the iPhone).
    private func attach(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
