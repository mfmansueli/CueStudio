//
//  ProfileUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Account, My Cue Voice, plan and paywall.
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

    func testANewProfileOffersToSetUpMyCueVoiceAndThenShowsWhatCueUses() {
        let app = openProfile()
        let setUp = app.buttons["profile.setUpVoiceButton"]
        XCTAssertTrue(setUp.waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["profile.voiceSample"].exists)
        setUp.tap()
        app.buttons["voiceSetup.skipRole"].tap()
        app.buttons["voiceSetup.niche.food"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.audience.simple"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.tone.casual"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        // The card now says what Cue uses; a row opens the question that holds it.
        XCTAssertTrue(app.staticTexts["profile.voiceSample"].waitForExistence(timeout: 5))
        let audience = app.buttons["profile.voiceRow.audience"]
        XCTAssertTrue(audience.waitForExistence(timeout: 5))
        audience.tap()
        XCTAssertTrue(app.buttons["voiceSetup.audience.technical"].waitForExistence(timeout: 5))
        app.buttons["sheet.closeButton"].tap()
    }

    func testVoicePreviewFollowsHowYouSound() {
        let app = openProfile()
        // The card shows the preview once My Cue Voice is set up.
        app.buttons["profile.setUpVoiceButton"].tap()
        app.buttons["voiceSetup.skipRole"].tap()
        app.buttons["voiceSetup.niche.food"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.audience.simple"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.tone.casual"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        let sample = app.staticTexts["profile.voiceSample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        XCTAssertTrue(sample.label.contains("So, real quick."))
        // The tone chosen in the questions is picked in "How I sound"; changing it changes the preview.
        let confident = app.buttons["profile.sound.Confident"]
        scroll(app, to: confident)
        XCTAssertTrue(app.buttons["profile.sound.Casual"].isSelected)
        XCTAssertFalse(confident.isSelected)
        confident.tap()
        XCTAssertTrue(confident.isSelected)
        app.buttons["profile.sound.Casual"].tap()
        XCTAssertFalse(app.buttons["profile.sound.Casual"].isSelected)
        XCTAssertTrue(app.staticTexts["profile.voiceSample"].label.contains("I'll say it"))
    }

    func testSignInWithAppleIsOfferedWhenSignedOut() {
        let app = openProfile()
        XCTAssertTrue(app.buttons["profile.signInButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.signOutButton"].exists)
    }

    func testProPlanHidesTheUpgrade() {
        let app = CueApp.launch(seeded: true, pro: true)
        app.cueTabBar.buttons["Profile"].tap()
        let pro = app.staticTexts["Cue Pro"]
        scroll(app, to: pro)
        XCTAssertFalse(app.buttons["profile.upgradeButton"].exists)
    }

    // MARK: - Helpers

    private func openProfile() -> XCUIApplication {
        let app = CueApp.launch(seeded: true)
        let tab = app.cueTabBar.buttons["Profile"]
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
