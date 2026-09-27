//
//  ProfileUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Plan, paywall and Creator DNA.
@MainActor
final class ProfileUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testUpgradeOpensAndClosesThePaywall() {
        let app = CueApp.launch(seeded: true)
        let profileTab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(profileTab.waitForExistence(timeout: 15))
        profileTab.tap()

        let upgrade = app.buttons["profile.upgradeButton"]
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
        upgrade.tap()
        let close = app.buttons["paywall.closeButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.plan.annual"].exists)
        close.tap()
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
    }

    func testAddingACatchphrase() {
        let app = CueApp.launch(seeded: true)
        app.tabBars.buttons["Profile"].tap()
        let add = app.buttons["profile.addPhraseButton"]
        XCTAssertTrue(add.waitForExistence(timeout: 5))
        add.tap()

        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Bora")
        app.alerts.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["“Bora”"].waitForExistence(timeout: 5))
    }

    func testProPlanHidesTheUpgrade() {
        let app = CueApp.launch(seeded: true, pro: true)
        app.tabBars.buttons["Profile"].tap()
        XCTAssertTrue(app.staticTexts["Cue Pro"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.upgradeButton"].exists)
    }
}
