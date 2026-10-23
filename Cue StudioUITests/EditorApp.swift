//
//  EditorApp.swift
//  Cue StudioUITests
//

import XCTest

/// Opens the editor on the "3 morning habits" take (a small real video), from its review.
@MainActor
enum EditorApp {
    /// `demo`: Take 3 is the v10 design's 21.6 s edit (`SampleEdit.demo`): two clips (cut at 12.4 s), eight caption lines, a title
    /// and a subtitle, four pauses already found, music with a beat under the whole video, a B-roll window (4.2–8 s) and a
    /// voice-over (0.5–4.5 s).
    static func open(sampleVideo: Bool = true, demo: Bool = false, arguments: [String] = []) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: sampleVideo, extraArguments: (demo ? ["-uiTestDemoEdit"] : []) + arguments)
        // Takes is the second tab; its label is "Takes" only in some languages (`-uiTestAppLanguage`).
        XCTAssertTrue(app.cueTabBar.exists(within: 15))
        let named = app.cueTabBar.buttons["Takes"]
        let tab = named.exists ? named : app.cueTabBar.buttons.element(boundBy: 1)
        XCTAssertTrue(tab.exists(within: 5))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.exists(within: 5))
        row.tap()
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.exists(within: 5))
        edit.tap()
        waitUntilReady(app)
        return app
    }

    /// The tools stay off until the video is ready (`isReady`), and the timeline then takes its place: a tap before that is lost.
    static func waitUntilReady(_ app: XCUIApplication, file: StaticString = #filePath, line: UInt = #line) {
        let tools = app.buttons["edit.toolbar.edit"]
        XCTAssertTrue(tools.exists(within: 10), "No editor", file: file, line: line)
        let deadline = Date().addingTimeInterval(10)
        while !tools.isEnabled, Date() < deadline { Thread.sleep(forTimeInterval: 0.1) }
        XCTAssertTrue(tools.isEnabled, "The editor's tools never turned on", file: file, line: line)
    }

    /// Taps a toolbar tool, scrolling the toolbar to it first when it's off screen.
    static func tapTool(_ app: XCUIApplication, _ id: String) {
        // Adjust and Background are Edit's clip tools (the main toolbar is Edit · Captions · Text · ✦ Smart · Media · Audio · Format ·
        // Filters · Cover); Format, the whole video's crop, is on the main bar.
        if ["adjust", "background", "reorder", "freeze"].contains(id), !app.buttons["edit.toolbar.\(id)"].exists,
           app.buttons["edit.toolbar.edit"].exists {
            app.buttons["edit.toolbar.edit"].tap()
        }
        let button = app.buttons["edit.toolbar.\(id)"]
        XCTAssertTrue(button.exists(within: 5), id)
        let screen = app.windows.firstMatch.frame
        var swipes = 0
        while !screen.contains(button.frame), swipes < 4 {
            // The tools run on past the screen's trailing edge: the right, and the left in Arabic.
            let toolbar = app.descendants(matching: .any)["edit.toolbar"]
            if button.frame.minX < screen.minX { toolbar.swipeRight() } else { toolbar.swipeLeft() }
            swipes += 1
        }
        button.tap()
    }

    /// Moves the playhead forward by dragging the timeline's content to the left, about
    /// `points` (44 points per second at the starting zoom), slowly and held at the end so it
    /// doesn't glide on.
    static func scrub(_ app: XCUIApplication, points: CGFloat = 300) {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        XCTAssertTrue(timeline.exists(within: 5))
        let width = timeline.frame.width
        let start = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).withOffset(CGVector(dx: points / 2, dy: 0))
        let end = start.withOffset(CGVector(dx: -min(points, width - 20), dy: 0))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: 400, thenHoldForDuration: 0.4)
    }

    /// A point on the video track, `x` of the way across the timeline (the playhead is at 0.5).
    static func mainTrack(_ app: XCUIApplication, at x: CGFloat) -> XCUICoordinate {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        XCTAssertTrue(timeline.exists(within: 5))
        // The video track starts under the ruler (24–28 pt) and is 44–56 pt tall.
        return timeline.coordinate(withNormalizedOffset: CGVector(dx: x, dy: 0)).withOffset(CGVector(dx: 0, dy: 50))
    }

    /// The player bar's "00:01.2 / 00:21.6": the edit's length (the part after the slash).
    static func length(_ app: XCUIApplication) -> String {
        let time = app.staticTexts["edit.timeLabel"].value as? String ?? ""
        return String((time.components(separatedBy: " / ").last ?? "").prefix(7))
    }

    /// Done always asks "Is it ready to post?": answers it (`ready` by default) and leaves the editor.
    static func done(_ app: XCUIApplication, answer: String = "ready") {
        app.buttons["edit.doneButton"].tap()
        let option = app.buttons["edit.done.\(answer)"]
        XCTAssertTrue(option.exists(within: 5), "No \(answer) answer")
        option.tap()
    }

    /// ✦ Smart › Remove pauses: opens the Pauses panel the way a creator reaches it now.
    static func openPauses(_ app: XCUIApplication) {
        tapTool(app, "smart")
        let tile = app.buttons["edit.smart.pauses"]
        XCTAssertTrue(tile.exists(within: 5))
        tile.tap()
    }

    /// Captions › the line at `index`: the playhead goes to its start. Closes the panel after.
    static func goToCaption(_ app: XCUIApplication, _ index: Int) {
        tapTool(app, "captions")
        let line = app.descendants(matching: .any)["edit.captionLine.\(index)"]
        XCTAssertTrue(line.exists(within: 5))
        line.tap()
        app.buttons["edit.panel.apply"].tap()
        // The line stays picked: back to the main tools.
        let back = app.buttons["edit.toolbar.back"]
        if back.exists(within: 2) { back.tap() }
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].exists(within: 5))
    }

    /// The editor's toast, once it says something containing `text`.
    /// A toast saying `text` shows. Matched by its words, not by the first toast found: the screen
    /// under the editor has a toast host of its own, and a toast with a button reads as a group there.
    static func toastSays(_ app: XCUIApplication, _ text: String, timeout: TimeInterval = 3) -> Bool {
        app.descendants(matching: .any).matching(identifier: "toast")
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            .exists(within: timeout)
    }

    /// A picture of the editor and its hierarchy, for `tools/contrast/audit.py`, when `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`
    /// asks for them.
    static func capture(_ app: XCUIApplication, _ name: String) {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { return }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
        try? app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }
}
