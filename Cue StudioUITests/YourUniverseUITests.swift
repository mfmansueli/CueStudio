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
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let link = element(app, "profile.universeLink")
        XCTAssertTrue(link.exists(within: 5))
        link.tap()
        XCTAssertTrue(element(app, "universe.screen").exists(within: 5))
        return app
    }

    func testTheLiveYearShowsItsCountAndPlanets() {
        let app = openUniverse("sample")
        XCTAssertEqual(element(app, "universe.headline").label, "23 VIDEOS SHARED IN \(year)")
        XCTAssertTrue(element(app, "universe.yearPicker").exists)
        XCTAssertTrue(element(app, "universe.planet.tiktok").exists)
        XCTAssertTrue(element(app, "universe.planet.reels").exists)
        XCTAssertTrue(element(app, "universe.planet.shorts").exists)
        XCTAssertFalse(element(app, "universe.sealedBadge").exists)
        // The milestones are the creator's life (64 shared over two years): every icon is won, so no card promises one.
        XCTAssertFalse(element(app, "universe.nextMilestone").exists)
        XCTAssertTrue(element(app, "universe.share").exists)
        XCTAssertTrue(element(app, "universe.theme.0").exists, "the themes sit under the map")
    }

    func testATapOnAPlanetSaysHowManyVideosAndHowFarTheNextDetailIs() {
        let app = openUniverse("sample")
        element(app, "universe.planet.tiktok").tap()
        XCTAssertTrue(app.staticTexts["12 VIDEOS IN \(year)"].exists(within: 5))
        XCTAssertTrue(app.staticTexts["40 more to unlock brighter glow"].exists)
        XCTAssertTrue(app.buttons["universe.planetSeeInTakes"].exists)
    }

    func testThePreviousYearIsSealed() {
        let app = openUniverse("sample")
        app.buttons["universe.year.previous"].tap()
        XCTAssertEqual(element(app, "universe.headline").label, "41 VIDEOS SHARED IN \(year - 1) · SEALED")
        XCTAssertTrue(element(app, "universe.sealedBadge").exists(within: 3))
        XCTAssertTrue(element(app, "universe.yearCard").exists, "a sealed year has its own card instead of the milestone")
        XCTAssertFalse(element(app, "universe.nextMilestone").exists)
    }

    /// ‹ year › in the bar: the arrows change the year, and the one with no year past it is off.
    func testTheArrowsBesideTheYearChangeIt() {
        let app = openUniverse("sample")
        let previous = app.buttons["universe.year.previous"]
        let next = app.buttons["universe.year.next"]
        XCTAssertEqual(element(app, "universe.year").label, "\(year)")
        XCTAssertFalse(next.isEnabled, "the live year is the newest")
        previous.tap()
        XCTAssertEqual(element(app, "universe.year").label, "\(year - 1)")
        XCTAssertEqual(element(app, "universe.headline").label, "41 VIDEOS SHARED IN \(year - 1) · SEALED")
        XCTAssertFalse(previous.isEnabled, "the sample has two years")
        next.tap()
        XCTAssertEqual(element(app, "universe.headline").label, "23 VIDEOS SHARED IN \(year)")
    }

    /// The map has no swipe of its own: a swipe across it is iOS's back swipe, which goes back to Profile (the owner, 31/10/2026).
    func testASwipeOnTheMapGoesBack() {
        let app = openUniverse("sample")
        // From the core in the middle of the map (far from the edge) to the right, the length of a thumb's swipe.
        let core = element(app, "universe.core").coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        core.press(forDuration: 0.05, thenDragTo: core.withOffset(CGVector(dx: 220, dy: 0)), withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(element(app, "profile.universeLink").exists(within: 5))
        XCTAssertFalse(element(app, "universe.screen").exists)
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
        XCTAssertTrue(app.staticTexts["Share 3 videos to unlock it"].exists(within: 3))
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
        XCTAssertTrue(element(app, "universeShare.kind").exists(within: 5))
        XCTAssertTrue(app.switches["universeShare.numbers"].exists)
        XCTAssertTrue(app.switches["universeShare.handle"].exists)
        XCTAssertTrue(app.buttons["universeShare.save"].exists && app.buttons["universeShare.share"].exists)
        app.buttons["6 s video"].tap()
        XCTAssertTrue(app.buttons["universeShare.share"].isEnabled)
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(element(app, "universe.screen").exists(within: 3))
    }

    func testTheStoryHasFiveSlidesAndEndsWithShare() {
        let app = openUniverse("sample")
        element(app, "universe.reviewRow").tap()
        XCTAssertTrue(element(app, "yearInReview.screen").exists(within: 5))
        XCTAssertFalse(element(app, "yearInReview.share").exists)
        for _ in 0..<4 { element(app, "yearInReview.next").tap() }
        XCTAssertTrue(element(app, "yearInReview.share").exists(within: 3), "the last slide offers Share my \(year)")
        element(app, "yearInReview.close").tap()
        XCTAssertTrue(element(app, "universe.screen").exists(within: 3))
    }

    /// "See in Takes ›" on a planet: Takes opens with the yellow "{YEAR} · SHARED ✕" chip, and ✕ clears it.
    func testSeeInTakesOpensTakesWithTheScopeChip() {
        let app = openUniverse("sample", seeded: true)
        element(app, "universe.planet.tiktok").tap()
        XCTAssertTrue(app.buttons["universe.planetSeeInTakes"].exists(within: 5))
        app.buttons["universe.planetSeeInTakes"].tap()
        let chip = element(app, "takes.scopeChip")
        XCTAssertTrue(chip.exists(within: 5))
        XCTAssertTrue(app.staticTexts["\(year) · SHARED"].exists)
        chip.tap()
        XCTAssertFalse(chip.exists(within: 2))
    }
}
