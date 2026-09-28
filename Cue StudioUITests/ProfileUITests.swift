//
//  ProfileUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Account, Creator Voice, plan and paywall.
@MainActor
final class ProfileUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testUpgradeOpensAndClosesThePaywall() {
        let app = openProfile()
        let upgrade = app.buttons["profile.upgradeButton"]
        scroll(app, to: upgrade)
        upgrade.tap()
        let close = app.buttons["paywall.closeButton"]
        XCTAssertTrue(close.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["paywall.plan.annual"].exists)
        XCTAssertTrue(app.buttons["paywall.plan.monthly"].exists)
        XCTAssertFalse(app.buttons["paywall.plan.lifetime"].exists)
        close.tap()
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
    }

    func testPaywallFooterOffersRestoreTermsAndPrivacy() {
        let app = openProfile()
        let upgrade = app.buttons["profile.upgradeButton"]
        scroll(app, to: upgrade)
        upgrade.tap()
        XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.links["Terms"].exists || app.buttons["Terms"].exists)
        app.buttons["paywall.privacyButton"].tap()
        XCTAssertTrue(app.navigationBars["Privacy & AI data"].waitForExistence(timeout: 5))
    }

    func testAddingACatchphrase() {
        let app = openProfile()
        let add = app.buttons["profile.addPhraseButton"]
        scroll(app, to: add)
        add.tap()

        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Bora")
        app.alerts.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["“Bora”"].waitForExistence(timeout: 5))
    }

    func testVoicePreviewFollowsHowYouSound() {
        let app = openProfile()
        let sample = app.staticTexts["profile.voiceSample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        XCTAssertTrue(sample.label.contains("So, real quick."))
        let casual = app.buttons["profile.sound.Casual"]
        scroll(app, to: casual)
        casual.tap()
        XCTAssertTrue(app.staticTexts["profile.voiceSample"].label.contains("I'll say it"))
    }

    func testSignInWithAppleIsOfferedWhenSignedOut() {
        let app = openProfile()
        XCTAssertTrue(app.buttons["profile.signInButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.signOutButton"].exists)
    }

    func testProPlanHidesTheUpgrade() {
        let app = CueApp.launch(seeded: true, pro: true)
        app.tabBars.buttons["Profile"].tap()
        let pro = app.staticTexts["Cue Pro"]
        scroll(app, to: pro)
        XCTAssertFalse(app.buttons["profile.upgradeButton"].exists)
    }

    // MARK: - Helpers

    private func openProfile() -> XCUIApplication {
        let app = CueApp.launch(seeded: true)
        let tab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        return app
    }

    /// The profile is a long list; rows below the fold only exist once scrolled to.
    private func scroll(_ app: XCUIApplication, to element: XCUIElement) {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }
}
