//
//  PersonalizeUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Settings › Personalize (owner's redesign, 21/10/2026): the live hero says what is chosen; a sky chosen from its card shows in the hero's
/// words; a locked icon stays unchosen; the switches of Feel and the topics are there. `CUE_SCREENSHOT_DIR` keeps pictures.
@MainActor
final class PersonalizeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        sleep(2)
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    private func openPersonalize(_ app: XCUIApplication) {
        app.cueTabBar.buttons["Settings"].tap()
        let row = element(app, "settings.personalize")
        for _ in 0..<4 where !(row.exists && row.isHittable) { app.swipeUp() }
        row.tap()
        XCTAssertTrue(element(app, "personalize.hero").exists(within: 5))
    }

    func testChoosingASkyShowsInTheHeroAndALockedIconStaysUnchosen() throws {
        let app = CueApp.launch(seeded: true)
        openPersonalize(app)
        let hero = element(app, "personalize.hero")
        // UI tests start with the sky off (`-uiTestSky off`).
        XCTAssertTrue(hero.label.contains("Default") && hero.label.contains("Off"), hero.label)
        try capture(app, "personalize_1_top")

        // Deep Space opens at 25 videos: tapping it keeps Default.
        app.buttons["settings.appIcon.deepSpace"].tap()
        XCTAssertTrue(app.buttons["settings.appIcon.standard"].isSelected)
        XCTAssertFalse(app.buttons["settings.appIcon.deepSpace"].isSelected)

        let adrift = app.buttons["settings.starrySky.adrift"]
        XCTAssertTrue(adrift.exists(within: 5))
        adrift.tap()
        XCTAssertTrue(adrift.isSelected)
        XCTAssertFalse(app.buttons["settings.starrySky.serene"].isSelected)
        let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label CONTAINS 'Adrift'"), object: hero)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 4), .completed)
        try capture(app, "personalize_2_adrift")

        app.swipeUp()
        XCTAssertTrue(element(app, "settings.celebrations").exists(within: 5))
        XCTAssertTrue(element(app, "settings.haptics").exists)
        XCTAssertTrue(element(app, "settings.autoTag").exists)
        try capture(app, "personalize_3_bottom")
    }
}
