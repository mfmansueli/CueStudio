//
//  YourUniverseUITests.swift
//  Cue StudioUITests
//

import XCTest

/// 9.2 · Your universe, one per year: the live year, a sealed one, the planets and their popover, the share sheet, the story, and the two empty
/// states. The data comes from `-uiTestUniverse` (the board's APP DATA panel).
@MainActor
final class YourUniverseUITests: XCTestCase {
    private let year = Calendar.current.component(.year, from: .now)

    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openUniverse(_ data: String, seeded: Bool = false) -> XCUIApplication {
        let app = CueApp.launch(seeded: seeded, extraArguments: ["-uiTestUniverse", data])
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let link = element(app, "profile.universeLink")
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(element(app, "universe.screen").waitForExistence(timeout: 5))
        return app
    }

    func testTheLiveYearShowsItsCountPlanetsAndMilestone() {
        let app = openUniverse("sample")
        XCTAssertEqual(element(app, "universe.headline").label, "23 VIDEOS SHARED IN \(year)")
        XCTAssertTrue(element(app, "universe.yearPicker").exists)
        XCTAssertTrue(element(app, "universe.planet.tiktok").exists)
        XCTAssertTrue(element(app, "universe.planet.reels").exists)
        XCTAssertTrue(element(app, "universe.planet.shorts").exists)
        XCTAssertFalse(element(app, "universe.sealedBadge").exists)
        XCTAssertTrue(element(app, "universe.nextMilestone").exists)
        XCTAssertTrue(element(app, "universe.share").exists)
        XCTAssertTrue(element(app, "universe.theme.0").exists, "the themes sit under the map")
    }

    func testATapOnAPlanetSaysHowManyVideosAndHowFarTheNextDetailIs() {
        let app = openUniverse("sample")
        element(app, "universe.planet.tiktok").tap()
        XCTAssertTrue(app.staticTexts["12 VIDEOS IN \(year)"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["40 more to unlock brighter glow"].exists)
        XCTAssertTrue(app.buttons["universe.planetSeeInTakes"].exists)
    }

    func testThePreviousYearIsSealed() {
        let app = openUniverse("sample")
        app.buttons["\(year - 1)"].tap()
        XCTAssertEqual(element(app, "universe.headline").label, "41 VIDEOS SHARED IN \(year - 1) · SEALED")
        XCTAssertTrue(element(app, "universe.sealedBadge").waitForExistence(timeout: 3))
        XCTAssertTrue(element(app, "universe.yearCard").exists, "a sealed year has its own card instead of the milestone")
        XCTAssertFalse(element(app, "universe.nextMilestone").exists)
    }

    func testTheYearCanBeChangedWithASwipeOnTheMap() {
        let app = openUniverse("sample")
        let map = element(app, "universe.core")
        map.swipeRight()
        XCTAssertEqual(element(app, "universe.headline").label, "41 VIDEOS SHARED IN \(year - 1) · SEALED")
    }

    func testANewAccountHasNoSelectorAndRecordsFirst() {
        let app = openUniverse("newAccount")
        XCTAssertEqual(element(app, "universe.headline").label, "NO VIDEOS SHARED YET")
        XCTAssertFalse(element(app, "universe.yearPicker").exists)
        XCTAssertTrue(element(app, "universe.caption").exists)
        XCTAssertTrue(element(app, "universe.firstStar").exists)
        XCTAssertTrue(element(app, "universe.record").exists)
        // The story is locked and says why.
        element(app, "universe.reviewRow").tap()
        XCTAssertTrue(app.staticTexts["Share 3 videos to unlock it"].waitForExistence(timeout: 3))
        XCTAssertFalse(element(app, "yearInReview.screen").exists)
    }

    func testANewYearOffersLastYearsUniverse() {
        let app = openUniverse("newYear")
        XCTAssertEqual(element(app, "universe.headline").label, "0 VIDEOS SHARED IN \(year)")
        XCTAssertTrue(element(app, "universe.firstStar").exists)
        XCTAssertTrue(app.buttons["Share my \(year - 1) universe"].exists)
        XCTAssertTrue(app.staticTexts["Your \(year - 1) in review"].exists)
    }

    func testTheShareSheetOffersImageOrVideoNumbersAndHandle() {
        let app = openUniverse("sample")
        element(app, "universe.share").tap()
        XCTAssertTrue(element(app, "universeShare.kind").waitForExistence(timeout: 5))
        XCTAssertTrue(app.switches["universeShare.numbers"].exists)
        XCTAssertTrue(app.switches["universeShare.handle"].exists)
        XCTAssertTrue(app.buttons["universeShare.save"].exists && app.buttons["universeShare.share"].exists)
        app.buttons["6 s video"].tap()
        XCTAssertTrue(app.buttons["universeShare.share"].isEnabled)
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(element(app, "universe.screen").waitForExistence(timeout: 3))
    }

    func testTheStoryHasFiveSlidesAndEndsWithShare() {
        let app = openUniverse("sample")
        element(app, "universe.reviewRow").tap()
        XCTAssertTrue(element(app, "yearInReview.screen").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "yearInReview.share").exists)
        for _ in 0..<4 { element(app, "yearInReview.next").tap() }
        XCTAssertTrue(element(app, "yearInReview.share").waitForExistence(timeout: 3), "the last slide offers Share my \(year)")
        element(app, "yearInReview.close").tap()
        XCTAssertTrue(element(app, "universe.screen").waitForExistence(timeout: 3))
    }

    /// "See in Takes ›" on a planet: Takes opens with the yellow "{YEAR} · SHARED ✕" chip, and ✕ clears it.
    func testSeeInTakesOpensTakesWithTheScopeChip() {
        let app = openUniverse("sample", seeded: true)
        element(app, "universe.planet.tiktok").tap()
        XCTAssertTrue(app.buttons["universe.planetSeeInTakes"].waitForExistence(timeout: 5))
        app.buttons["universe.planetSeeInTakes"].tap()
        let chip = element(app, "takes.scopeChip")
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["\(year) · SHARED"].exists)
        chip.tap()
        XCTAssertFalse(chip.waitForExistence(timeout: 2))
    }
}
