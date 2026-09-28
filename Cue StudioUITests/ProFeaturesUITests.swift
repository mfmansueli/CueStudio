//
//  ProFeaturesUITests.swift
//  Cue StudioUITests
//

import XCTest

/// What Cue Pro unlocks outside exports: the full Creator Voice, versions for other platforms and
/// best-take suggestions. Free opens the paywall for its context; Pro just works.
@MainActor
final class ProFeaturesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testVocabularyIsProOnTheFreePlan() {
        let app = CueApp.launch(seeded: true)
        let tab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let vocabulary = app.segmentedControls["profile.vocabulary"]
        for _ in 0..<6 where !(vocabulary.exists && vocabulary.isHittable) { app.swipeUp() }
        vocabulary.buttons["Technical"].tap()
        XCTAssertTrue(app.staticTexts["AI that sounds like you"].waitForExistence(timeout: 5))
        app.buttons["paywall.closeButton"].tap()
        XCTAssertFalse(app.segmentedControls["profile.vocabulary"].buttons["Technical"].isSelected)
    }

    func testMakingAVersionForAnotherPlatform() {
        let app = openScript(pro: true)
        openVersionMenu(app)
        app.buttons["TikTok"].tap()
        XCTAssertTrue(app.staticTexts["TikTok version saved as a copy"].waitForExistence(timeout: 10))
    }

    func testVersionsOpenThePaywallOnTheFreePlan() {
        let app = openScript(pro: false)
        openVersionMenu(app)
        app.buttons["TikTok"].tap()
        XCTAssertTrue(app.staticTexts["One script, every platform"].waitForExistence(timeout: 5))
    }

    func testSuggestBestPicksATakeOnPro() {
        let app = openReview(pro: true)
        let suggest = app.buttons["review.suggestBestButton"]
        XCTAssertTrue(suggest.waitForExistence(timeout: 5))
        suggest.tap()
        let toast = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'looks best'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
    }

    func testSuggestBestIsProOnTheFreePlan() {
        let app = openReview(pro: false)
        let suggest = app.buttons["review.suggestBestButton"]
        XCTAssertTrue(suggest.waitForExistence(timeout: 5))
        suggest.tap()
        XCTAssertTrue(app.staticTexts["Let Cue pick your best take"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func openScript(pro: Bool) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, pro: pro)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.buttons["detail.editButton"].waitForExistence(timeout: 5))
        return app
    }

    /// The sample script is for Reels, so the menu offers every other platform. On the free plan
    /// the item also reads "Pro".
    private func openVersionMenu(_ app: XCUIApplication) {
        app.navigationBars.buttons["More"].tap()
        let versions = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Make a version for'")).firstMatch
        XCTAssertTrue(versions.waitForExistence(timeout: 5))
        versions.tap()
        XCTAssertTrue(app.buttons["TikTok"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Instagram Reels"].exists)
    }

    private func openReview(pro: Bool) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, pro: pro)
        let tab = app.tabBars.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        return app
    }
}
