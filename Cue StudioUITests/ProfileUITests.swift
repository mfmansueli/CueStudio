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
        // The regular Pro: Cue's marketing above the system's plans; the opening takes 2.4 s and the list is there when it ends.
        XCTAssertTrue(app.descendants(matching: .any)["paywall.benefits"].firstMatch.waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["Take your universe further."].exists)
        close.tap()
        XCTAssertTrue(upgrade.waitForExistence(timeout: 5))
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

    /// Sign in with Apple lives at the end of Fine-tune (My Cue Voice › Fine-tune how you sound), optional like everything about an account.
    func testSignInWithAppleIsOfferedWhenSignedOut() {
        let app = openProfile()
        setUpVoice(app)
        openVoicePage(app)
        let fineTune = app.staticTexts["Fine-tune how you sound"]
        app.scroll(to: fineTune)
        fineTune.tap()
        let signIn = app.buttons["profile.signInButton"]
        app.scroll(to: signIn)
        XCTAssertTrue(signIn.exists)
        XCTAssertFalse(app.buttons["profile.signOutButton"].exists)
    }

    /// The creative preferences are with the fine-tuning (My Cue Voice › Fine-tune), not in Settings or in the board's Edit Profile, and they survive
    /// tab changes.
    func testCreativePreferencesLiveInFineTuneAndSurviveTabChanges() {
        let app = openProfile()
        setUpVoice(app)
        openVoicePage(app)
        let fineTune = app.staticTexts["Fine-tune how you sound"]
        app.scroll(to: fineTune)
        fineTune.tap()
        let goals = app.switches["profile.monetizationGoalsToggle"]
        app.scroll(to: goals)
        XCTAssertTrue(app.buttons["profile.defaultPlatformPicker"].exists)
        goals.tap()
        let saved = goals.value as? String
        // Settings has none of them.
        app.cueTabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.recording"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.switches["profile.monetizationGoalsToggle"].exists)
        // Back on the Profile tab, the page is where it was left, with the value kept.
        app.cueTabBar.buttons["Profile"].tap()
        let again = app.switches["profile.monetizationGoalsToggle"]
        app.scroll(to: again)
        XCTAssertEqual(again.value as? String, saved)
    }

    /// Edit Profile (9.1): Done waits for a valid name and username; it saves them and says so.
    func testEditProfileSavesAValidDraftAndRefusesAnInvalidOne() {
        let app = openProfile()
        let identity = app.descendants(matching: .any)["profile.creatorCard"].firstMatch
        identity.tap()
        let name = app.textFields["editProfile.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        let done = app.buttons["editProfile.doneButton"]
        let handle = app.textFields["editProfile.handleField"]
        name.tap()
        name.typeText("Maya Costa")
        handle.tap()
        handle.typeText("M")
        XCTAssertFalse(done.isEnabled, "a one-letter username is not enough")
        XCTAssertTrue(app.staticTexts["editProfile.handleError"].exists)
        handle.typeText("aya Cooks")
        XCTAssertEqual(handle.value as? String, "mayacooks", "the field keeps the username lowercase and without spaces")
        XCTAssertTrue(done.isEnabled)
        done.tap()
        XCTAssertTrue(app.staticTexts["Profile updated"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Maya Costa"].waitForExistence(timeout: 5))
    }

    func testCancelLeavesTheProfileAsItWas() {
        let app = openProfile()
        let identity = app.descendants(matching: .any)["profile.creatorCard"].firstMatch
        identity.tap()
        let name = app.textFields["editProfile.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Someone Else")
        app.buttons["editProfile.cancelButton"].tap()
        XCTAssertFalse(app.staticTexts["Someone Else"].waitForExistence(timeout: 2))
    }

    /// Edit in the toolbar and the long press on the identity open the same sheet (9.1).
    func testEditButtonAndContextMenuOpenEditProfile() {
        let app = openProfile()
        app.buttons["profile.editButton"].tap()
        XCTAssertTrue(app.buttons["editProfile.doneButton"].waitForExistence(timeout: 5))
        app.buttons["editProfile.cancelButton"].tap()
        let identity = app.descendants(matching: .any)["profile.creatorCard"].firstMatch
        XCTAssertTrue(identity.waitForExistence(timeout: 5))
        identity.press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 5))
        app.buttons["Edit profile"].tap()
        XCTAssertTrue(app.buttons["editProfile.doneButton"].waitForExistence(timeout: 5))
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
