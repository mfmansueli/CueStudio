//
//  FreePlanUITests.swift
//  Cue StudioUITests
//

import XCTest

/// On the free plan every feature works, with no PRO badges: the full Creator Voice, versions for
/// other platforms and best-take suggestions. Only exporting past the free five opens the paywall.
@MainActor
final class FreePlanUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testVocabularyIsFree() {
        let app = CueApp.launch(seeded: true)
        let tab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let vocabulary = app.segmentedControls["profile.vocabulary"]
        for _ in 0..<6 where !(vocabulary.exists && vocabulary.isHittable) { app.swipeUp() }
        vocabulary.buttons["Technical"].tap()
        XCTAssertFalse(app.buttons["paywall.closeButton"].waitForExistence(timeout: 2))
        XCTAssertTrue(vocabulary.buttons["Technical"].isSelected)
    }

    func testMakingAVersionForAnotherPlatform() {
        let app = openScript()
        app.navigationBars.buttons["More"].tap()
        let versions = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Make a version for'")).firstMatch
        XCTAssertTrue(versions.waitForExistence(timeout: 5))
        versions.tap()
        // The sample script is for Reels, so the menu offers every other platform.
        XCTAssertTrue(app.buttons["TikTok"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Instagram Reels"].exists)
        app.buttons["TikTok"].tap()
        XCTAssertTrue(app.staticTexts["TikTok version saved as a copy"].waitForExistence(timeout: 10))
    }

    func testSuggestBestPicksATake() {
        let app = CueApp.launch(seeded: true)
        let tab = app.tabBars.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let suggest = app.buttons["review.suggestBestButton"]
        XCTAssertTrue(suggest.waitForExistence(timeout: 5))
        suggest.tap()
        let toast = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'looks best'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
    }

    func testSponsoredAdIsAFreeFormat() {
        let app = CueApp.launch(seeded: true)
        let newScript = app.buttons["scripts.newButton"]
        XCTAssertTrue(newScript.waitForExistence(timeout: 15))
        newScript.tap()
        let formats = app.buttons["newScript.formats"]
        XCTAssertTrue(formats.waitForExistence(timeout: 5))
        formats.tap()
        let ad = app.buttons["generate.type.ad"]
        XCTAssertTrue(ad.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["PRO"].exists)
        ad.tap()
        XCTAssertFalse(app.buttons["paywall.closeButton"].waitForExistence(timeout: 2))
    }

    // MARK: - Helpers

    private func openScript() -> XCUIApplication {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.buttons["detail.editButton"].waitForExistence(timeout: 5))
        return app
    }
}
