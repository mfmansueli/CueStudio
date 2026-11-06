//
//  FluidityDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Each place of the app moved the way a creator moves it (lists flung and dragged, a long script scrolled and typed into, the
/// universe, the editor playing and scrubbing, the recorder), on a real iPhone, for `tools/motion/screen_frames.sh` to count the frames
/// the screen shows: each test prints `CUE-MARK <Unix time> go` as its movement starts. In memory and seeded, real animations.
/// Opt-in: `CUE_DEVICE=… tools/motion/fluidity.sh` runs them all (or `screen_frames.sh FluidityDeviceUITests/<test> <folder> go 0 12`).
@MainActor
final class FluidityDeviceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_MOTION"] != nil else {
            throw XCTSkip("Device film: TEST_RUNNER_CUE_MOTION=1")
        }
    }

    private func go() {
        print(String(format: "CUE-MARK %.3f %@", Date().timeIntervalSince1970, "go"))
    }

    /// The tab by its place (the iPhone's language names them): Scripts, Takes, Record, Profile, Settings.
    private func tab(_ app: XCUIApplication, _ name: String) {
        let index = ["Scripts", "Takes", "Record", "Profile", "Settings"].firstIndex(of: name) ?? 0
        XCTAssertTrue(app.cueTabBar.exists(within: 20), "No tab bar")
        let button = app.cueTabBar.buttons.element(boundBy: index)
        XCTAssertTrue(button.exists(within: 5), "No \(name) tab")
        button.tap()
    }

    /// Flung up twice and back, three times, let go each time.
    private func fling(_ element: XCUIElement) {
        for _ in 0..<3 {
            for _ in 0..<2 { element.swipeUp(velocity: .fast); sleep(1) }
            for _ in 0..<2 { element.swipeDown(velocity: .fast); sleep(1) }
        }
    }

    /// Dragged up and down with the finger held.
    private func drag(_ element: XCUIElement, times: Int = 5) {
        let low = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
        let high = element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.3))
        for _ in 0..<times {
            low.press(forDuration: 0.05, thenDragTo: high, withVelocity: 400, thenHoldForDuration: 0.2)
            high.press(forDuration: 0.05, thenDragTo: low, withVelocity: 400, thenHoldForDuration: 0.2)
        }
    }

    // MARK: - Lists

    func testTakesList() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, animations: true)
        tab(app, "Takes")
        sleep(3)
        go()
        let window = app.windows.firstMatch
        fling(window)
        drag(window, times: 2)
    }

    func testLogbook() {
        let app = CueApp.launch(seeded: true, animations: true)
        let logbook = app.buttons["scripts.logbookButton"]
        XCTAssertTrue(logbook.exists(within: 20))
        logbook.tap()
        sleep(2)
        go()
        let window = app.windows.firstMatch
        fling(window)
        drag(window, times: 2)
    }

    func testProfileAndUniverse() {
        let app = CueApp.launch(seeded: true, animations: true, extraArguments: ["-uiTestUniverse", "sample"])
        tab(app, "Profile")
        sleep(3)
        go()
        let window = app.windows.firstMatch
        fling(window)
        drag(window, times: 2)
    }

    func testSettings() {
        let app = CueApp.launch(seeded: true, animations: true)
        tab(app, "Settings")
        sleep(2)
        go()
        let window = app.windows.firstMatch
        fling(window)
        drag(window, times: 2)
    }

    /// Scripts → Takes → Record → Profile → Settings → Scripts, twice.
    func testSwitchingTabs() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, animations: true)
        XCTAssertTrue(app.cueTabBar.exists(within: 20))
        sleep(2)
        go()
        for _ in 0..<2 {
            for name in ["Takes", "Profile", "Settings", "Scripts"] {
                tab(app, name)
                usleep(1_200_000)
            }
        }
    }

    // MARK: - Ideas and scripts

    func testFindInspiration() {
        let app = CueApp.launch(seeded: true, animations: true)
        let open = app.buttons["ideaCard.inspirationButton"]
        XCTAssertTrue(open.exists(within: 20))
        go()
        open.tap()
        sleep(3)
        let all = app.buttons["inspiration.filter.all"]
        if all.exists {
            all.tap()
            sleep(1)
            all.tap()
            sleep(1)
        }
        let window = app.windows.firstMatch
        for _ in 0..<3 {
            window.swipeLeft()
            sleep(1)
        }
        app.buttons["sheet.closeButton"].tap()
        sleep(1)
    }

    /// The long script's page (443 words) flung and dragged, with no keyboard.
    func testLongScriptScrolling() {
        let app = openLongScript()
        let words = app.textViews["page.editor"]
        sleep(2)
        go()
        fling(words)
        drag(words, times: 2)
    }

    /// Letters typed into the long script's words, the keyboard up.
    func testLongScriptTyping() {
        let app = openLongScript()
        let words = app.textViews["page.editor"]
        words.tap()
        sleep(2)
        go()
        for _ in 0..<3 {
            words.typeText("the quick brown fox jumps over the lazy dog ")
        }
    }

    private func openLongScript() -> XCUIApplication {
        let app = CueApp.launch(seeded: true, animations: true, extraArguments: ["-uiTestLongScript"])
        let send = app.buttons["ideaCard.submit"]
        XCTAssertTrue(send.exists(within: 20))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: send)
        waitForExpectations(timeout: 30)
        send.tap()
        let words = app.textViews["page.editor"]
        XCTAssertTrue(words.exists(within: 30), "No page for the long script")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: app.textFields["page.titleField"])
        waitForExpectations(timeout: 30)
        return app
    }

    // MARK: - Recording and editing

    /// The recorder open on a script (camera, teleprompter) for a few seconds, and closed.
    func testRecorder() {
        let app = CueApp.launch(seeded: true, animations: true, extraArguments: ["-uiTestPermissions", "granted"])
        XCTAssertTrue(app.cueTabBar.exists(within: 20))
        sleep(2)
        go()
        tab(app, "Record")
        sleep(10)
    }

    /// A take's review playing.
    func testReviewPlaying() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, animations: true)
        tab(app, "Takes")
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.exists(within: 10))
        sleep(1)
        go()
        row.tap()
        sleep(8)
    }

    /// The demo edit playing, then its timeline dragged back and forth.
    func testEditorPlayingAndScrubbing() {
        let app = EditorApp.open(demo: true, animations: true)
        sleep(2)
        go()
        let play = app.buttons["edit.playButton"]
        if play.exists {
            play.tap()
            sleep(5)
            play.tap()
        }
        let timeline = app.descendants(matching: .any)["edit.timeline"].firstMatch
        if timeline.exists {
            let right = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.8, dy: 0.5))
            let left = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.5))
            for _ in 0..<3 {
                right.press(forDuration: 0.05, thenDragTo: left, withVelocity: 300, thenHoldForDuration: 0.2)
                left.press(forDuration: 0.05, thenDragTo: right, withVelocity: 300, thenHoldForDuration: 0.2)
            }
        }
    }

    /// The editor's tools opened one after another (Text, Captions, Audio, Filters), each bar or panel coming in and going back.
    func testEditorPanels() {
        let app = EditorApp.open(demo: true, animations: true)
        sleep(2)
        go()
        for tool in ["text", "captions", "audio", "filters"] {
            EditorApp.tapTool(app, tool)
            sleep(2)
            let back = app.buttons["edit.toolbar.back"]
            if back.exists { back.tap() }
            sleep(1)
        }
    }
}
