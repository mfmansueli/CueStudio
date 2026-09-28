//
//  ShareToUITests.swift
//  Cue StudioUITests
//

import XCTest

/// "Share to" from a take's review: the platforms, captions and quality (4K on every plan).
@MainActor
final class ShareToUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testShareToListsEveryPlatformWithTheOneItWasMadeFor() {
        let app = openShareTo()
        let tiktok = app.buttons["share.tiktok"]
        XCTAssertEqual(tiktok.label, "TikTok, recommended")
        for identifier in ["share.reels", "share.shorts", "share.youtube", "share.linkedin", "share.stories", "share.save", "share.more"] {
            XCTAssertTrue(app.buttons[identifier].exists, identifier)
        }
        XCTAssertTrue(app.staticTexts["Created for TikTok — framed and safe-zoned for it"].exists)
        XCTAssertTrue(app.switches["share.captionsToggle"].exists)
    }

    func testFourKIsFree() {
        let app = openShareTo()
        let quality = app.segmentedControls["share.quality"]
        quality.buttons["4K"].tap()
        XCTAssertTrue(quality.buttons["4K"].isSelected)
        XCTAssertFalse(app.buttons["paywall.closeButton"].exists)
    }

    // MARK: - Helpers

    private func openShareTo(pro: Bool = false) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, pro: pro)
        let tab = app.tabBars.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let share = app.buttons["review.shareButton"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.buttons["share.tiktok"].waitForExistence(timeout: 5))
        return app
    }
}
