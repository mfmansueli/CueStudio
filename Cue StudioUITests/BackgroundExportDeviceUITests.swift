//
//  BackgroundExportDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Exports with Cue in the background, on an iPhone (opt-in:
/// `CUE_DEVICE=… TEST_RUNNER_CUE_BACKGROUND_EXPORT=1 scripts/test.sh device-ui BackgroundExportDeviceUITests[/test]`):
/// - `testSaveGoesOnWithCueInTheBackground`: Save on the REAL newest take, the Home screen and the Camera (which wants the GPU
///   too) for 40 s, then back: the video was saved. It adds a video to Photos, so only on a phone whose owner said so.
/// - the long-take tests: a 150 s full-size take with captions (in memory, nothing of the creator's touched), rendered by
///   Share to universe (nothing goes to Photos): in Cue as the reference, then with Cue away for 60 s, and a 400 s take that
///   runs past the seconds iOS gives an app that leaves. Each prints what it saw on return and how long it took.
@MainActor
final class BackgroundExportDeviceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testSaveGoesOnWithCueInTheBackground() throws {
        guard ProcessInfo.processInfo.environment["CUE_BACKGROUND_EXPORT"] != nil else {
            throw XCTSkip("Only on a phone whose owner agreed: TEST_RUNNER_CUE_BACKGROUND_EXPORT=1")
        }
        let app = XCUIApplication()
        app.launch()
        let takes = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(takes.exists(within: 20))
        takes.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.'")).firstMatch
        XCTAssertTrue(row.exists(within: 10), "No take in the library")
        print("BACKGROUND EXPORT · take: \(row.label)")
        row.tap()
        let save = app.buttons["review.saveButton"]
        XCTAssertTrue(save.exists(within: 10))
        let started = Date()
        save.tap()

        let mode = app.staticTexts["review.export.mode"]
        XCTAssertTrue(mode.exists(within: 15), "The export didn't say how it runs")
        print("BACKGROUND EXPORT · mode: \(mode.label)")

        // Away from Cue, with another app that wants the GPU.
        XCUIDevice.shared.press(.home)
        let camera = XCUIApplication(bundleIdentifier: "com.apple.camera")
        camera.activate()
        sleep(40)
        app.activate()

        let ready = app.descendants(matching: .any)["ready.sheet"]
        let saved = ready.exists(within: 120)
        let seconds = Int(Date().timeIntervalSince(started))
        let progress = app.descendants(matching: .any)["review.export.progress"]
        print("BACKGROUND EXPORT · saved: \(saved) · \(seconds) s from Save · still exporting on return: \(progress.exists)")
        XCTAssertTrue(saved, "The video wasn't saved")
    }

    // MARK: - Long take

    func testLongTakeRenderedInCue() throws {
        try measureLongRender(arguments: [], leaves: false)
    }

    func testLongTakeRenderedWithCueAwayAndNoTask() throws {
        try measureLongRender(arguments: [], leaves: true)
    }

    /// Longer than the few seconds iOS gives an app that leaves: what the export does past them.
    func testVeryLongTakeRenderedWithCueAwayAndNoTask() throws {
        try measureLongRender(arguments: [], leaves: true, seconds: 400)
    }

    private func measureLongRender(arguments: [String], leaves: Bool, seconds: Int = 150) throws {
        guard ProcessInfo.processInfo.environment["CUE_BACKGROUND_EXPORT"] != nil else {
            throw XCTSkip("Device measurement: TEST_RUNNER_CUE_BACKGROUND_EXPORT=1")
        }
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestLongTake", "\(seconds)"] + arguments)
        let takes = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(takes.exists(within: 120), "The long take wasn't written in time")
        takes.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.exists(within: 10))
        row.tap()
        let share = app.buttons["review.shareButton"]
        XCTAssertTrue(share.exists(within: 10))
        let started = Date()
        share.tap()
        let mode = app.staticTexts["review.export.mode"]
        XCTAssertTrue(mode.exists(within: 15), "The export didn't say how it runs")
        let label = mode.label
        var onReturn = "stayed in Cue"
        if leaves {
            XCUIDevice.shared.press(.home)
            XCUIApplication(bundleIdentifier: "com.apple.camera").activate()
            sleep(60)
            app.activate()
            let progress = app.descendants(matching: .any)["review.export.progress"]
            let ready = app.descendants(matching: .any)["ready.sheet"]
            let toast = app.descendants(matching: .any).matching(identifier: "toast").firstMatch
            onReturn = ready.exists ? "done" : progress.exists ? "still exporting (\(progress.label))"
                : toast.exists ? "toast: \(toast.label)" : "nothing"
            print("LONG RENDER · \(name) · on return after \(Int(Date().timeIntervalSince(started))) s: \(onReturn)")
            if !progress.exists, !ready.exists { return }
        }
        let picker = app.descendants(matching: .any)["ready.sheet"]
        let done = picker.exists(within: 200)
        let toast = app.descendants(matching: .any).matching(identifier: "toast").firstMatch
        print("LONG RENDER · \(name) · mode: \(label) · on return: \(onReturn) · done: \(done) · \(Int(Date().timeIntervalSince(started))) s"
            + (done ? "" : " · toast: \(toast.exists ? toast.label : "none")"))
        XCTAssertTrue(done, "The long take wasn't rendered")
    }
}
