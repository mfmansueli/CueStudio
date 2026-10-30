//
//  ShareUniverseProV29UITests.swift
//  Cue StudioUITests
//

import XCTest

/// v29 · phase 7: Your universe (the animated core and its colours, the empty state) on a new install. The paywall is `ProfileUITests`'.
/// Pictures are saved when `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` is set.
@MainActor
final class ShareUniverseProV29UITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openUniverse(_ app: XCUIApplication) {
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        XCTAssertTrue(element(app, "profile.creatorCard").exists(within: 5), "A new install's Profile has no creator card")
        let card = element(app, "profile.universeLink")
        var swipes = 0
        while !card.isHittable, swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        card.tap()
        XCTAssertTrue(element(app, "universe.screen").exists(within: 5))
    }

    /// 9.2 with nothing shared: the map shows the core alone and the empty state invites the first star.
    func testYourUniverseWithNothingSharedShowsTheCoreAndTheEmptyState() {
        let app = CueApp.launch(seeded: false)
        openUniverse(app)
        XCTAssertTrue(app.staticTexts["Your universe starts with your first share."].exists(within: 5))
        XCTAssertTrue(element(app, "universe.record").exists)
        capture(app, "9.2_universe_empty")
    }

    /// 9.2: tapping the core opens its sheet; each colour chosen there is the one marked (the same choice lives in Settings › Personalize).
    func testTappingTheCoreOpensItsSheetWithTheFourColours() {
        let app = CueApp.launch(seeded: false)
        openUniverse(app)
        element(app, "universe.core").tap()
        XCTAssertTrue(element(app, "universeCore.sheet").exists(within: 5))
        XCTAssertTrue(app.staticTexts["Your light. It grows with every video you share. No photo needed."].exists)
        for color in ["gold", "amber", "sunrise", "rose"] {
            XCTAssertTrue(app.buttons["coreColor.\(color)"].exists, color)
        }
        XCTAssertTrue(app.buttons["coreColor.gold"].isSelected)
        app.buttons["coreColor.rose"].tap()
        XCTAssertTrue(app.buttons["coreColor.rose"].isSelected)
        XCTAssertFalse(app.buttons["coreColor.gold"].isSelected)
        capture(app, "9.2_core_sheet")
        for color in ["amber", "sunrise", "gold"] {
            let chip = app.buttons["coreColor.\(color)"]
            chip.tap()
            XCTAssertTrue(chip.isSelected, "\(color) was tapped and is not the one selected")
        }
    }
}
