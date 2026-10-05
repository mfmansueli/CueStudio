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
        app.scroll(to: upgrade)
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
        app.scroll(to: upgrade)
        upgrade.tap()
        XCTAssertTrue(app.buttons["Restore"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.links["Terms"].exists || app.buttons["Terms"].exists)
        app.buttons["paywall.privacyButton"].tap()
        XCTAssertTrue(app.navigationBars["Privacy & AI data"].waitForExistence(timeout: 5))
    }

    /// A catchphrase is an answer of "My phrases" on the full page (9.3): the question sheet opens with its field ready.
    func testAddingACatchphrase() {
        // The "Saved" shows for 0.9 s before the sheet closes; without the closing animation it can be gone before the test looks.
        let app = openProfile(animations: true)
        setUpVoice(app)
        openVoicePage(app)
        let row = app.buttons["voicePage.row.phrases"]
        app.scroll(to: row)
        row.tap()
        let field = app.descendants(matching: .any)["voice.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText("Bora")
        app.buttons["voice.add"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["voice.saved"].waitForExistence(timeout: 5))
    }

    func testANewProfileOffersToSetUpMyCueVoiceAndThenShowsWhatCueUses() {
        let app = openProfile()
        let setUp = app.buttons["profile.setUpVoiceButton"]
        XCTAssertTrue(setUp.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.editVoice"].exists)
        setUpVoice(app)
        // The card now says what Cue uses; a row opens the question that holds it.
        openVoicePage(app)
        let audience = app.buttons["voicePage.row.audience"]
        XCTAssertTrue(audience.waitForExistence(timeout: 5))
        audience.tap()
        XCTAssertTrue(app.descendants(matching: .any)["voice.option.technical"].waitForExistence(timeout: 5))
        app.buttons["sheet.closeButton"].tap()
    }

    /// The card's ✦ Preview shows a line in the creator's voice once My Cue Voice is set up.
    func testVoicePreviewFollowsHowYouSound() {
        let app = openProfile()
        setUpVoice(app)
        let preview = app.buttons["profile.voicePreview"]
        app.scroll(to: preview)
        preview.tap()
        let sample = app.staticTexts["profile.voiceSample"]
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
        XCTAssertTrue(sample.label.contains("So, real quick."))
    }

    /// Sign in with Apple lives in the profile sheet (the identity row opens it), optional like everything about an account.
    func testSignInWithAppleIsOfferedWhenSignedOut() {
        let app = openProfile()
        let identity = app.descendants(matching: .any)["profile.creatorCard"].firstMatch
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        identity.tap()
        XCTAssertTrue(app.buttons["profile.signInButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["profile.signOutButton"].exists)
    }

    func testProPlanHidesTheUpgrade() {
        let app = CueApp.launch(seeded: true, pro: true)
        app.cueTabBar.buttons["Profile"].tap()
        let pro = app.staticTexts["Cue Pro"]
        app.scroll(to: pro)
        XCTAssertFalse(app.buttons["profile.upgradeButton"].exists)
    }

    // MARK: - Helpers

    private func openProfile(animations: Bool = false) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, animations: animations)
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        return app
    }

    /// The four questions of a new voice, answered the shortest way.
    private func setUpVoice(_ app: XCUIApplication) {
        app.buttons["profile.setUpVoiceButton"].tap()
        app.buttons["voiceSetup.skipRole"].tap()
        app.buttons["voiceSetup.niche.food"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.audience.simple"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.tone.casual"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
    }

    /// Profile › Edit voice: the full page (9.3).
    private func openVoicePage(_ app: XCUIApplication) {
        let edit = app.buttons["profile.editVoice"]
        app.scroll(to: edit)
        edit.tap()
    }
}
