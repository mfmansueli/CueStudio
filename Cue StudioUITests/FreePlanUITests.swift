//
//  FreePlanUITests.swift
//  Cue StudioUITests
//

import XCTest

/// On the free plan every feature works, with no PRO badges: the full My Cue Voice, versions for
/// other platforms and best-take suggestions. Only exporting past the free five opens the paywall.
@MainActor
final class FreePlanUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// The audience (the words Cue uses) is part of the voice setup, free like everything else but exporting.
    func testVocabularyIsFree() {
        let app = CueApp.launch(seeded: true)
        let chip = app.buttons["ideaCard.voiceChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        app.buttons["voiceSetup.skipRole"].tap()
        app.buttons["voiceSetup.niche.tech"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        let technical = app.buttons["voiceSetup.audience.insiders"]
        XCTAssertTrue(technical.waitForExistence(timeout: 5))
        technical.tap()
        XCTAssertFalse(app.buttons["paywall.closeButton"].waitForExistence(timeout: 2))
        XCTAssertTrue(technical.isSelected)
    }

    func testMakingAVersionForAnotherPlatform() {
        let app = openScript()
        app.buttons["page.menuButton"].tap()
        let versions = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Make a version for'")).firstMatch
        XCTAssertTrue(versions.waitForExistence(timeout: 5))
        versions.tap()
        // The sample script is for Reels, so the menu offers every other platform.
        XCTAssertTrue(app.buttons["TikTok"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Instagram Reels"].exists)
        app.buttons["TikTok"].tap()
        // The toast passes quickly: what lasts is the copy in the library.
        app.pageBackButton.tap()
        XCTAssertTrue(app.staticTexts["Unboxing the Lumen desk lamp (TikTok)"].waitForExistence(timeout: 10))
    }

    func testSuggestBestPicksATake() {
        let app = CueApp.launch(seeded: true)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let pill = app.descendants(matching: .any)["review.takeLabel"].firstMatch
        XCTAssertTrue(pill.waitForExistence(timeout: 5))
        pill.tap()
        let suggest = app.buttons["Suggest best"]
        XCTAssertTrue(suggest.waitForExistence(timeout: 3))
        suggest.tap()
        // "Pick your best take": Cue's suggestion in the middle, with why; "Use take N" keeps it.
        XCTAssertTrue(app.descendants(matching: .any)["pick.sheet"].firstMatch.waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["pick.reasons"].firstMatch.waitForExistence(timeout: 5))
        app.buttons["pick.use"].tap()
        let toast = app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'marked as best'")).firstMatch
        XCTAssertTrue(toast.waitForExistence(timeout: 5))
    }

    func testSponsoredAdIsAFreeFormat() {
        let app = CueApp.launch(seeded: true)
        let chip = app.buttons["ideaCard.formatChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        let ad = app.buttons["format.ad"]
        XCTAssertTrue(ad.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["PRO"].exists)
        ad.tap()
        XCTAssertFalse(app.buttons["paywall.closeButton"].waitForExistence(timeout: 2))
    }

    // MARK: - Helpers

    private func openScript() -> XCUIApplication {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 5))
        return app
    }
}
