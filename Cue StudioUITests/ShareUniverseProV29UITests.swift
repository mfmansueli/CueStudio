//
//  ShareUniverseProV29UITests.swift
//  Cue StudioUITests
//

import XCTest

/// v29 · phase 7: Your universe (the animated core, the empty state), the paywall and the export screens. Pictures are
/// saved when `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` is set.
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
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let card = element(app, "profile.universeCard")
        var swipes = 0
        while !card.isHittable, swipes < 5 {
            app.swipeUp()
            swipes += 1
        }
        card.tap()
        XCTAssertTrue(element(app, "universe.screen").waitForExistence(timeout: 5))
    }

    /// 9.2 with nothing shared: the map shows the core alone and the empty state invites the first star.
    func testYourUniverseWithNothingSharedShowsTheCoreAndTheEmptyState() {
        let app = CueApp.launch(seeded: false)
        openUniverse(app)
        XCTAssertTrue(app.staticTexts["Your first star is one video away"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "universe.empty.action").exists)
        capture(app, "9.2_universe_empty")
    }

    /// 11.4 from the Profile: the plans, the trial button and Restore are all there.
    func testThePaywallShowsPlansTheTrialAndRestore() {
        let app = CueApp.launch(seeded: false)
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let upgrade = element(app, "profile.upgradeButton")
        var swipes = 0
        while !upgrade.isHittable, swipes < 6 {
            app.swipeUp()
            swipes += 1
        }
        upgrade.tap()
        XCTAssertTrue(app.buttons["paywall.buyButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Restore"].exists)
        capture(app, "11.4_pro")
    }
}
