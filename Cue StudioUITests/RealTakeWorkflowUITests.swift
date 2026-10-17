//
//  RealTakeWorkflowUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The whole creator day on a REAL take of the iPhone it runs on (not in memory, nothing seeded): open the newest take, take out
/// the pauses, make captions from the real voice, cut words by text, put on a template, set the cover, and Download video to
/// Photos. It edits that take and adds a video to Photos, so it is opt-in, only for a phone whose owner said so:
/// `CUE_DEVICE=… TEST_RUNNER_CUE_REAL_TAKE_UI=1 scripts/test.sh device-ui RealTakeWorkflowUITests`.
@MainActor
final class RealTakeWorkflowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testADayOfEditingOnTheNewestTake() throws {
        guard ProcessInfo.processInfo.environment["CUE_REAL_TAKE_UI"] != nil else {
            throw XCTSkip("Only on a phone whose owner agreed: TEST_RUNNER_CUE_REAL_TAKE_UI=1")
        }
        let app = XCUIApplication()
        app.launch()
        allowSystemAlerts()
        let flow = CreatorWorkflow("real-take", app: app)

        flow.step("Takes › the newest take › Edit")
        let takes = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(takes.waitForExistence(timeout: 20))
        takes.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "No take in the library")
        print("CREATOR STEP real-take · take: \(row.label)")
        flow.tap(row, "the newest take")
        flow.tap(app.buttons["review.editButton"], "Edit")
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].waitForExistence(timeout: 20), "The editor didn't open")
        let start = Date()

        flow.step("✦ Smart › Remove pauses")
        flow.tool("smart")
        flow.tap(app.buttons["edit.smart.pauses"], "Remove pauses")
        let apply = app.buttons["edit.pauses.apply"]
        if apply.waitForExistence(timeout: 60), apply.isEnabled {
            flow.tap(apply, "Remove the pauses")
            print("CREATOR STEP real-take · pauses removed: \(flow.toastSays("Removed", timeout: 10))")
        } else {
            print("CREATOR STEP real-take · no pauses to remove")
        }
        closePanel(app)

        flow.step("Captions from the voice")
        flow.tool("captions")
        let make = app.buttons["edit.captionsMakeButton"]
        if make.waitForExistence(timeout: 5) { flow.tap(make, "Make captions") }
        let line = app.descendants(matching: .any)["edit.captionLine.0"]
        XCTAssertTrue(line.waitForExistence(timeout: 120), "No caption line from the real voice in 2 minutes")
        flow.capture("captions")
        closePanel(app)

        flow.step("✦ Smart › Edit by text › cut two words")
        flow.tool("smart")
        flow.tap(app.buttons["edit.smart.editByText"], "Edit by text")
        let firstWord = app.buttons["edit.transcript.word.4"]
        if !firstWord.waitForExistence(timeout: 5) {
            let listen = app.buttons["edit.transcript.listen"]
            if listen.exists { flow.tap(listen, "Listen to the video") }
        }
        XCTAssertTrue(firstWord.waitForExistence(timeout: 120), "Edit by text has no words for the real voice")
        // Two words in a row still in the video (a run before this one may have cut some: they stay listed, crossed out).
        let pick = try XCTUnwrap((4..<60).first { index in
            [index, index + 1].allSatisfy { word in
                let button = app.buttons["edit.transcript.word.\(word)"]
                return button.exists && !button.label.hasSuffix(", cut")
            }
        }, "No two words in a row left to cut")
        print("CREATOR STEP real-take · cutting words \(pick) and \(pick + 1)")
        flow.tap(app.buttons["edit.transcript.word.\(pick)"], "the first word")
        XCTAssertTrue(app.descendants(matching: .any)["edit.transcript.pickGuide"].waitForExistence(timeout: 3), "No guide after the first word")
        flow.tap(app.buttons["edit.transcript.word.\(pick + 1)"], "the last word")
        flow.tap(app.buttons["edit.transcript.cut"], "Cut from video")
        XCTAssertTrue(flow.toastSays("Words cut", timeout: 5), "No toast after cutting")
        flow.capture("cut")
        // The sheet's ×: a swipe on the words scrolls them instead of closing it.
        flow.tap(app.buttons["sheet.closeButton"].firstMatch, "Edit by text's ×")
        XCTAssertFalse(firstWord.waitForExistence(timeout: 2), "Edit by text stayed open")

        flow.step("✦ Smart › Templates › Bold hook")
        flow.tool("smart")
        flow.tap(app.buttons["edit.smart.section.templates"], "Templates")
        flow.tap(app.buttons["edit.template.boldHook"], "Bold hook")
        XCTAssertTrue(flow.toastSays("Bold hook", timeout: 5))
        flow.capture("bold-hook")
        closePanel(app)

        flow.step("Cover › Done")
        flow.tool("cover")
        let coverDone = app.buttons["cover.done"]
        XCTAssertTrue(coverDone.waitForExistence(timeout: 10))
        flow.tap(coverDone, "Done on the cover")

        flow.step("Done › Download video")
        flow.tap(app.buttons["edit.doneButton"], "Done")
        flow.tap(app.buttons["edit.done.download"], "Download video")
        allowSystemAlerts()
        let notice = app.descendants(matching: .any)["review.exportNotice"]
        let saved = flow.toastSays("Photos", timeout: 180) || notice.waitForExistence(timeout: 5)
        flow.capture("downloaded")
        print("CREATOR STEP real-take · editing and download took \(Int(Date().timeIntervalSince(start))) s · saved: \(saved)")
        XCTAssertTrue(saved, "Download video didn't say the video went to Photos")
        flow.report()
    }

    /// ✓ on whatever panel is open, then back to the main tools.
    private func closePanel(_ app: XCUIApplication) {
        let apply = app.buttons["edit.panel.apply"]
        if apply.waitForExistence(timeout: 2) { apply.tap() }
        let back = app.buttons["edit.toolbar.back"]
        if back.waitForExistence(timeout: 2) { back.tap() }
    }

    /// The system's Photos or speech prompts, answered yes (the owner agreed to this run).
    private func allowSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow Full Access", "Allow", "OK", "Permitir Acesso Total", "Permitir", "Ok"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 1) { button.tap() }
        }
    }
}
