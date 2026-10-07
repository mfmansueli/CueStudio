//
//  EditorApp.swift
//  Cue StudioUITests
//

import XCTest

/// Opens the editor on the "3 morning habits" take (a small real video), from its review.
@MainActor
enum EditorApp {
    /// `demo`: Take 3 is the v10 design's 21.6 s edit (`SampleEdit`): eight caption lines, a title
    /// and a subtitle, and four pauses already found.
    static func open(sampleVideo: Bool = true, demo: Bool = false, arguments: [String] = []) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: sampleVideo, extraArguments: (demo ? ["-uiTestDemoEdit"] : []) + arguments)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].waitForExistence(timeout: 10))
        return app
    }

    /// Taps a toolbar tool, scrolling the toolbar to it first when it's off screen.
    static func tapTool(_ app: XCUIApplication, _ id: String) {
        // Adjust, Crop, Background and Overlay are Edit's clip tools in v29 (the main toolbar is Edit · Audio · Text · Captions · Filters · Smart · Cover).
        if ["adjust", "crop", "background", "media"].contains(id), !app.buttons["edit.toolbar.\(id)"].exists,
           app.buttons["edit.toolbar.edit"].exists {
            app.buttons["edit.toolbar.edit"].tap()
        }
        let button = app.buttons["edit.toolbar.\(id)"]
        XCTAssertTrue(button.waitForExistence(timeout: 5), id)
        let screen = app.windows.firstMatch.frame
        var swipes = 0
        while !screen.contains(button.frame), swipes < 4 {
            app.descendants(matching: .any)["edit.toolbar"].swipeLeft()
            swipes += 1
        }
        button.tap()
    }

    /// Moves the playhead forward by dragging the timeline's content to the left, about
    /// `points` (44 points per second at the starting zoom), slowly and held at the end so it
    /// doesn't glide on.
    static func scrub(_ app: XCUIApplication, points: CGFloat = 300) {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 5))
        let width = timeline.frame.width
        let start = timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.06)).withOffset(CGVector(dx: points / 2, dy: 0))
        let end = start.withOffset(CGVector(dx: -min(points, width - 20), dy: 0))
        start.press(forDuration: 0.1, thenDragTo: end, withVelocity: 400, thenHoldForDuration: 0.4)
    }

    /// A point on the video track, `x` of the way across the timeline (the playhead is at 0.5).
    static func mainTrack(_ app: XCUIApplication, at x: CGFloat) -> XCUICoordinate {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 5))
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
        XCTAssertTrue(option.waitForExistence(timeout: 5), "No \(answer) answer")
        option.tap()
    }

    /// ✦ Smart › Remove pauses: opens the Pauses panel the way a creator reaches it now.
    static func openPauses(_ app: XCUIApplication) {
        tapTool(app, "smart")
        let tile = app.buttons["edit.smart.pauses"]
        XCTAssertTrue(tile.waitForExistence(timeout: 5))
        tile.tap()
    }

    /// Captions › the line at `index`: the playhead goes to its start. Closes the panel after.
    static func goToCaption(_ app: XCUIApplication, _ index: Int) {
        tapTool(app, "captions")
        let line = app.descendants(matching: .any)["edit.captionLine.\(index)"]
        XCTAssertTrue(line.waitForExistence(timeout: 5))
        line.tap()
        app.buttons["edit.panel.apply"].tap()
        // The line stays picked: back to the main tools.
        let back = app.buttons["edit.toolbar.back"]
        if back.waitForExistence(timeout: 2) { back.tap() }
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].waitForExistence(timeout: 5))
    }

    /// The editor's toast, once it says something containing `text`.
    /// A toast saying `text` shows. Matched by its words, not by the first toast found: the screen
    /// under the editor has a toast host of its own, and a toast with a button reads as a group there.
    static func toastSays(_ app: XCUIApplication, _ text: String, timeout: TimeInterval = 3) -> Bool {
        app.descendants(matching: .any).matching(identifier: "toast")
            .matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
            .waitForExistence(timeout: timeout)
    }
}
