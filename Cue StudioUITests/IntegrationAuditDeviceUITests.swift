//
//  IntegrationAuditDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The integration audit's fixes walked on a real iPhone the way a creator would, in memory (the creator's library, drafts and Photos are
/// never touched; the share sheet is the test's own): the countdown left for the Home Screen (A9), leaving the review mid-export (B2),
/// exporting with an edit left open (B4), and captions an export heard while a draft waited, reached through the queue's "Edit first" on
/// its second network, whose next Share goes on from there (B20 + B9: real speech, heard by the iPhone).
/// Opt-in: `CUE_DEVICE=… TEST_RUNNER_CUE_AUDIT_UI=1 [TEST_RUNNER_CUE_REAL_TAKE=<file>] scripts/test.sh device-ui IntegrationAuditDeviceUITests`.
/// B20 + B9 needs a take with speech: a file name in Takes, or a video copied to the app's Documents
/// (`xcrun devicectl device copy to … --domain-identifier com.cuestudioteleprompter --destination Documents/speech.mov`) named
/// `../../../Documents/speech.mov`. Made with ffmpeg, give it PCM sound (`-c:a pcm_s16le`): an AAC track ffmpeg wrote comes out of the
/// audio extraction a packet longer than it decodes, and the recognizer stops at that packet ("Couldn’t listen to this take").
@MainActor
final class IntegrationAuditDeviceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_AUDIT_UI"] != nil else {
            throw XCTSkip("Only on a phone whose owner agreed: TEST_RUNNER_CUE_AUDIT_UI=1")
        }
    }

    // MARK: - A9

    /// Home during the countdown stops it: coming back, nothing records.
    func testLeavingCueDuringTheCountdownRecordsNothing() {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.exists(within: 15))
        record.tap()
        allowSystemAlerts()
        let shutter = app.buttons["prompter.recordButton"]
        XCTAssertTrue(shutter.exists(within: 15), "The recorder didn't open")
        // The camera running (its message gone) before Record.
        sleep(2)
        shutter.tap()
        XCTAssertTrue(app.descendants(matching: .any)["prompter.countdown"].exists(within: 3), "No countdown")
        XCUIDevice.shared.press(.home)
        sleep(6)
        app.activate()
        XCTAssertTrue(shutter.exists(within: 10))
        sleep(2)
        attach(app, "A9 back after Home")
        XCTAssertFalse(app.descendants(matching: .any)["prompter.recordingBadge"].exists, "A take started while Cue was away")
        XCTAssertFalse(app.descendants(matching: .any)["prompter.countdown"].exists, "The countdown went on")
        app.buttons["prompter.closeButton"].tap()
    }

    // MARK: - B2

    /// Back during an export asks "Cancel export?": Keep exporting goes on, Cancel export leaves and nothing is delivered.
    func testLeavingTheReviewMidExportAsksAndCancelling() {
        let app = openSampleReview(["-uiTestSlowExport"])
        app.buttons["review.shareButton"].tap()
        let progress = app.descendants(matching: .any)["review.export.progress"]
        XCTAssertTrue(progress.exists(within: 10), "No export under way")
        app.buttons["review.backButton"].tap()
        let keep = app.alerts.buttons["Keep exporting"]
        XCTAssertTrue(keep.exists(within: 5), "Back didn't ask")
        attach(app, "B2 Cancel export")
        keep.tap()
        XCTAssertTrue(progress.exists, "Keep exporting stopped it")
        app.buttons["review.backButton"].tap()
        let cancel = app.alerts.buttons["Cancel export"]
        XCTAssertTrue(cancel.exists(within: 5))
        cancel.tap()
        XCTAssertTrue(app.cueTabBar.buttons["Takes"].exists(within: 10), "Cancel export didn't leave the review")
        sleep(8)
        XCTAssertFalse(app.descendants(matching: .any)["shareFlow.start"].exists, "A cancelled export was delivered")
        XCTAssertFalse(app.descendants(matching: .any)["ready.sheet"].exists, "A cancelled export was delivered")
    }

    // MARK: - B4

    /// Save with an edit left open asks first; Cancel exports nothing.
    func testSavingWithAnEditLeftOpenAsksFirst() {
        let app = EditorApp.open()
        makeAChange(app)
        EditorApp.done(app, answer: "notYet")
        let save = app.buttons["review.saveButton"]
        XCTAssertTrue(save.exists(within: 10))
        save.tap()
        let alert = app.alerts["Unfinished edit"]
        XCTAssertTrue(alert.exists(within: 5), "Save didn't ask about the open edit")
        XCTAssertTrue(alert.buttons["Keep editing"].exists)
        XCTAssertTrue(alert.buttons["Export original"].exists, "A take never finished should offer the original")
        attach(app, "B4 Unfinished edit")
        alert.buttons["Cancel"].tap()
        XCTAssertFalse(app.descendants(matching: .any)["review.export.progress"].exists(within: 2), "Cancel exported")
    }

    // MARK: - B20 + B9

    /// A draft left open, the video shared to two networks with burned-in captions (heard by this iPhone), the first posted, "Edit first" on
    /// the second: the editor has the captions the export heard, and Share again goes on with the second network only.
    func testCaptionsHeardMeanwhileAndTheQueueGoingOnAfterEditFirst() throws {
        guard let take = ProcessInfo.processInfo.environment["CUE_REAL_TAKE"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_REAL_TAKE to a take's file name on the iPhone (one with speech)")
        }
        // Real animations: ending the share sheet hands back to the queue only with them (as in CueUniverseScreenshotTests).
        let app = EditorApp.open(animations: true, arguments: ["-uiTestRealTake", take, "-uiTestFakeShareSheet"])
        makeAChange(app)
        EditorApp.done(app, answer: "notYet")

        // B4 again on the way: the original goes out, the draft waits.
        let share = app.buttons["review.shareButton"]
        XCTAssertTrue(share.exists(within: 10))
        share.tap()
        let original = app.alerts.buttons["Export original"]
        XCTAssertTrue(original.exists(within: 5), "Share didn't ask about the open edit")
        original.tap()
        let start = app.buttons["shareFlow.start"]
        XCTAssertTrue(start.exists(within: 180), "No networks after the export")

        // Two networks, captions burned in, nothing to Photos.
        pick(app, ["tiktok", "reels"])
        app.buttons["shareFlow.options"].tap()
        let captions = app.switches["share.captionsToggle"]
        XCTAssertTrue(captions.exists(within: 5))
        if captions.value as? String != "1" { toggle(captions) }
        attach(app, "B20 captions on")
        app.buttons["exportOptions.back"].tap()
        let photos = app.switches["shareFlow.saveToPhotos"]
        if photos.exists(within: 3), photos.value as? String == "1" {
            app.scroll(to: photos)
            toggle(photos)
        }
        app.scroll(to: start)
        start.tap()

        // The export hears the take (real speech): then the queue's first network.
        let explainer = app.buttons["shareFlow.explainerStart"]
        let step = app.descendants(matching: .any)["shareFlow.step"]
        let deadline = Date().addingTimeInterval(300)
        while Date() < deadline, !step.exists {
            if explainer.exists { explainer.tap() }
            usleep(500_000)
        }
        XCTAssertTrue(step.exists, "No first network after the captioned export")
        let missing = app.descendants(matching: .any)["shareFlow.missingCaptions"]
        XCTAssertFalse(missing.exists, "The export made no captions: \(missing.exists ? missing.label : "")")
        let first = app.descendants(matching: .any)["shareFlow.position"].label
        attach(app, "B9 first network")
        app.buttons["shareFlow.send"].tap()
        XCTAssertTrue(app.buttons["debug.share.complete"].exists(within: 20), "The share sheet didn't open")
        app.buttons["debug.share.complete"].tap()
        XCTAssertTrue(app.buttons["shareFlow.live"].exists(within: 20), "No question whether it was posted")
        app.buttons["shareFlow.live"].tap()

        // The second network: Edit first.
        let editFirst = app.buttons["shareFlow.editFirst"]
        XCTAssertTrue(editFirst.exists(within: 20), "No second network step")
        let second = app.descendants(matching: .any)["shareFlow.position"].label
        XCTAssertNotEqual(first, second)
        editFirst.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].exists(within: 20), "Edit first didn't open the editor")

        // B20: the captions the export heard are in the draft.
        EditorApp.tapTool(app, "captions")
        let line = app.descendants(matching: .any)["edit.captionLine.0"]
        XCTAssertTrue(line.exists(within: 15), "The draft lost the captions the export heard")
        attach(app, "B20 captions in the draft")
        closePanel(app)

        // B9: Done › share, and the queue goes on with the second network, not the first again.
        EditorApp.done(app, answer: "share")
        let deadline2 = Date().addingTimeInterval(300)
        while Date() < deadline2, !step.exists, !start.exists {
            if explainer.exists { explainer.tap() }
            usleep(500_000)
        }
        if start.exists, !step.exists {
            app.scroll(to: start)
            start.tap()
            let deadline3 = Date().addingTimeInterval(300)
            while Date() < deadline3, !step.exists {
                if explainer.exists { explainer.tap() }
                usleep(500_000)
            }
        }
        XCTAssertTrue(step.exists(within: 5), "No network step after sharing the edit")
        attach(app, "B9 after Edit first")
        XCTAssertEqual(app.descendants(matching: .any)["shareFlow.position"].label, second, "The queue started over")
    }

    // MARK: - Helpers

    /// "3 morning habits" Take 3's review, with small real videos behind the sample takes.
    private func openSampleReview(_ arguments: [String]) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: arguments)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.exists(within: 5))
        row.tap()
        XCTAssertTrue(app.buttons["review.shareButton"].exists(within: 10))
        return app
    }

    /// A cut in the middle: a change that would change the video.
    private func makeAChange(_ app: XCUIApplication) {
        EditorApp.tapTool(app, "edit")
        EditorApp.scrub(app)
        EditorApp.tapTool(app, "split")
    }

    /// Exactly `networks` ticked in "Share to universe".
    private func pick(_ app: XCUIApplication, _ networks: [String]) {
        for network in ["tiktok", "reels", "shorts", "youtube", "linkedin"] {
            let row = app.buttons["shareFlow.network.\(network)"]
            guard row.exists(within: 3) else { continue }
            if row.isSelected != networks.contains(network) { row.tap() }
        }
    }

    /// A switch's own control (a tap on its label doesn't turn it).
    private func toggle(_ element: XCUIElement) {
        let control = element.switches.firstMatch
        if control.exists { control.tap() } else { element.tap() }
    }

    private func closePanel(_ app: XCUIApplication) {
        let apply = app.buttons["edit.panel.apply"]
        if apply.exists(within: 2) { apply.tap() }
        let back = app.buttons["edit.toolbar.back"]
        if back.exists(within: 2) { back.tap() }
    }

    private func allowSystemAlerts() {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow", "OK", "Allow While Using App", "Permitir", "Ok"] {
            let button = springboard.buttons[label]
            if button.exists(within: 1) { button.tap() }
        }
    }

    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
