//
//  CardDepthCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// A picture of every list that has cards (7/10/2026: the cards are a little 3D, `cardDepth`), to look at the shadow and the light on
/// the edge in place: Scripts, the Logbook, Takes as a grid and as a list, Profile, Settings and its pages, My Cue Voice, and the sheets
/// whose options are cards. Opt in with `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`; each group starts from a fresh launch and a control
/// that is not found only skips its picture.
@MainActor
final class CardDepthCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = true
    }

    private func shot(_ app: XCUIApplication, _ name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: "depth-\(name).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Taps a control by identifier when it is there; false when it is not.
    @discardableResult
    private func tap(_ app: XCUIApplication, _ id: String, wait: TimeInterval = 5) -> Bool {
        let control = element(app, id)
        guard control.waitForExistence(timeout: wait), control.isHittable else { return false }
        control.tap()
        sleep(1)
        return true
    }

    private func launch() -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: true)
        _ = app.buttons["ideaCard.submit"].waitForExistence(timeout: 20)
        return app
    }

    private func openTab(_ app: XCUIApplication, _ index: Int) {
        let bar = app.cueTabBar
        if bar.waitForExistence(timeout: 5) { bar.buttons.element(boundBy: index).tap(); sleep(1) }
    }

    func testScriptsAndTheLogbook() throws {
        let app = launch()
        try shot(app, "01-scripts")
        app.swipeUp()
        try shot(app, "02-scripts-end")
        if tap(app, "scripts.logbookButton") {
            try shot(app, "03-logbook")
        }
    }

    func testTakesAsGridAndList() throws {
        let app = launch()
        openTab(app, 1)
        try shot(app, "04-takes-grid")
        let list = app.segmentedControls["takes.layout"].buttons["List"]
        if list.waitForExistence(timeout: 4) {
            list.tap()
            try shot(app, "05-takes-list")
        }
    }

    func testProfileAndMyCueVoice() throws {
        let app = launch()
        openTab(app, 3)
        try shot(app, "06-profile")
        app.swipeUp()
        try shot(app, "07-profile-2")
        openTab(app, 4)
        if tap(app, "settings.myCueVoice") {
            try shot(app, "11-my-cue-voice")
        }
    }

    func testSettingsAndItsPages() throws {
        let app = launch()
        openTab(app, 4)
        try shot(app, "08-settings")
        app.swipeUp()
        try shot(app, "09-settings-end")
        app.swipeDown()
        if tap(app, "settings.recording") {
            try shot(app, "10-settings-recording")
        }
    }

    func testSwipeActionsOnScriptsAndTakes() throws {
        let app = launch()
        let script = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.'")).firstMatch
        if script.waitForExistence(timeout: 5) {
            script.swipeLeft()
            try shot(app, "14-swipe-scripts")
        }
        openTab(app, 1)
        let list = app.segmentedControls["takes.layout"].buttons["List"]
        if list.waitForExistence(timeout: 4) {
            list.tap()
            let video = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.'")).firstMatch
            if video.waitForExistence(timeout: 5) {
                video.swipeLeft()
                try shot(app, "15-swipe-takes")
            }
        }
    }

    func testSheetsWhoseOptionsAreCards() throws {
        let app = launch()
        if tap(app, "ideaCard.formatChip") {
            try shot(app, "12-format-sheet")
            app.swipeDown(velocity: .fast)
            sleep(1)
        }
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.'")).firstMatch
        if row.waitForExistence(timeout: 5) {
            row.tap()
            if tap(app, "page.improveButton") {
                try shot(app, "13-improve-sheet")
            }
        }
    }
}
