//
//  EditorApp.swift
//  Cue StudioUITests
//

import XCTest

/// Opens the editor on the "3 morning habits" take (a small real video), from its review.
@MainActor
enum EditorApp {
    static func open(sampleVideo: Bool = true) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: sampleVideo)
        let tab = app.tabBars.buttons["Takes"]
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

    /// Moves the playhead to `fraction` of the video by tapping the timeline there.
    static func seek(_ app: XCUIApplication, to fraction: CGFloat) {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        XCTAssertTrue(timeline.waitForExistence(timeout: 5))
        timeline.coordinate(withNormalizedOffset: CGVector(dx: fraction, dy: 0.5)).tap()
    }

    /// Plays for about `seconds`, then pauses.
    static func play(_ app: XCUIApplication, for seconds: UInt32) {
        app.buttons["edit.playButton"].tap()
        sleep(seconds)
        app.buttons["edit.playButton"].tap()
    }
}
