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

    /// A catchphrase is an answer of "My phrases" on the full page (9.3): the editor opens on it and the phrase stays in the list.
    func testAddingACatchphrase() {
        let app = openProfile()
        setUpVoice(app)
        openVoicePage(app)
        let row = app.buttons["voicePage.row.phrases"]
        app.scroll(to: row)
        row.tap()
        XCTAssertTrue(app.descendants(matching: .any)["voice.editor.phrases"].waitForExistence(timeout: 5))
        let field = app.textFields["voice.phrases.field"]
        app.scroll(to: field)
        field.tap()
        field.typeText("Bora")
        app.buttons["voice.phrases.field.add"].tap()
        XCTAssertTrue(app.staticTexts["“Bora”"].waitForExistence(timeout: 5))
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
        XCTAssertTrue(app.descendants(matching: .any)["voiceSetup.audience.insiders"].waitForExistence(timeout: 5))
        app.buttons["voice.editor.done"].tap()
    }

    /// The card's ✦ Preview shows a sample in the creator's voice once My Cue Voice is set up.
    func testVoicePreviewFollowsHowYouSound() {
        let app = openProfile()
        setUpVoice(app)
        let preview = app.buttons["profile.voicePreview"]
        app.scroll(to: preview)
        preview.tap()
        let card = app.descendants(matching: .any)["voice.preview.card"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        // The tone chosen in the setup is the conversational one: its line is the one the sample opens with.
        XCTAssertTrue(card.label.contains("I used to hit snooze four times."))
    }

    /// Sign in with Apple lives in Edit Profile, optional like everything about an account.
    func testSignInWithAppleIsOfferedWhenSignedOut() {
        let app = openProfile()
        app.descendants(matching: .any)["profile.creatorCard"].firstMatch.tap()
        XCTAssertTrue(app.textFields["editProfile.nameField"].waitForExistence(timeout: 5))
        let signIn = app.buttons["profile.signInButton"]
        app.scroll(to: signIn)
        XCTAssertTrue(signIn.exists)
        XCTAssertFalse(app.buttons["profile.signOutButton"].exists)
    }

    /// The creative preferences are in Edit Profile (kept with Done), not in Settings or on the voice page, and they survive tab changes.
    func testCreativePreferencesLiveInEditProfileAndSurviveTabChanges() {
        let app = openProfile()
        app.descendants(matching: .any)["profile.creatorCard"].firstMatch.tap()
        let name = app.textFields["editProfile.nameField"]
        XCTAssertTrue(name.waitForExistence(timeout: 5))
        name.tap()
        name.typeText("Maya Costa")
        let handle = app.textFields["editProfile.handleField"]
        handle.tap()
        handle.typeText("mayacooks")
        let goals = app.switches["profile.monetizationGoalsToggle"]
        app.scroll(to: goals)
        XCTAssertTrue(app.descendants(matching: .any)["profile.defaultPlatformPicker"].firstMatch.exists)
        goals.tap()
        let saved = goals.value as? String
        app.buttons["editProfile.doneButton"].tap()
        // Settings has none of them.
        app.cueTabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.recording"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.switches["profile.monetizationGoalsToggle"].exists)
        // Back on the Profile tab, Edit Profile shows the value kept.
        app.cueTabBar.buttons["Profile"].tap()
        app.descendants(matching: .any)["profile.creatorCard"].firstMatch.tap()
        let again = app.switches["profile.monetizationGoalsToggle"]
        app.scroll(to: again)
        XCTAssertEqual(again.value as? String, saved)
    }

    /// The owner's report (21/10/2026): with no name and no username, Done was off and nothing else could be saved. Both are optional now.
    func testDoneSavesWithoutANameOrAUsername() {
        let app = openProfile()
        app.descendants(matching: .any)["profile.creatorCard"].firstMatch.tap()
        let done = app.buttons["editProfile.doneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 5))
        XCTAssertTrue(done.isEnabled)
        done.tap()
        XCTAssertTrue(app.staticTexts["Profile updated"].waitForExistence(timeout: 5))
    }

    /// Pictures of the Profile, empty (a new install) and with a year in it (`CUE_SCREENSHOT_DIR`); without the folder it only checks the cards.
    func testTheProfileEmptyAndFull() throws {
        for (name, arguments) in [("profile_empty", [String]()), ("profile_full", ["-uiTestUniverse", "sample"])] {
            let app = CueApp.launch(seeded: !arguments.isEmpty, extraArguments: arguments)
            let tab = app.cueTabBar.buttons["Profile"]
            XCTAssertTrue(tab.waitForExistence(timeout: 15))
            tab.tap()
            XCTAssertTrue(app.descendants(matching: .any)["profile.creatorCard"].firstMatch.waitForExistence(timeout: 5))
            XCTAssertTrue(app.descendants(matching: .any)["profile.universeLink"].firstMatch.exists)
            if let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] {
                sleep(2)
                try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "\(name).png"))
            }
            app.terminate()
        }
    }

    /// The mini universe moves as soon as the Profile opens (owner's report, 21/10/2026: it stood still until the universe screen had been
    /// opened and left): two pictures of its card, 1.5 s apart, differ.
    func testTheMiniUniverseMovesAsSoonAsTheProfileOpens() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUniverse", "sample"])
        app.cueTabBar.buttons["Profile"].tap()
        let card = app.descendants(matching: .any)["profile.universeLink"].firstMatch
        XCTAssertTrue(card.waitForExistence(timeout: 5))
        sleep(1)
        let first = card.screenshot().pngRepresentation
        Thread.sleep(forTimeInterval: 1.5)
        XCTAssertNotEqual(first, card.screenshot().pngRepresentation, "the mini universe stood still")
    }

    /// The camera badge opens the photo library (owner's report, 21/10/2026: inside a menu, the picker never opened).
    func testTheCameraBadgeOpensThePhotoLibrary() throws {
        let app = openProfile()
        app.descendants(matching: .any)["profile.creatorCard"].firstMatch.tap()
        let badge = app.buttons["editProfile.photoButton"]
        XCTAssertTrue(badge.waitForExistence(timeout: 5))
        badge.tap()
        // The library is another process: the sheet under it stops being the one in front, so its Done can no longer be reached.
        let covered = XCTNSPredicateExpectation(predicate: NSPredicate(format: "isHittable == false"), object: app.buttons["editProfile.doneButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [covered], timeout: 8), .completed, "the photo library didn't open")
        if let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] {
            sleep(2)
            try XCUIScreen.main.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "edit_profile_picker.png"))
        }
    }

    /// "What you make" takes a type of the creator's own (owner's ask, 21/10/2026): typed into the chip, chosen, shown on the preview and,
    /// once saved, on the profile.
    func testAddingACreatorTypeOfYourOwn() throws {
        let app = openProfile()
        app.descendants(matching: .any)["profile.creatorCard"].firstMatch.tap()
        let add = app.buttons["editProfile.role.add"]
        app.scroll(to: add)
        if let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "edit_profile_1.png"))
        }
        add.tap()
        let field = app.textFields["editProfile.role.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Podcaster\n")
        XCTAssertTrue(app.descendants(matching: .any)["editProfile.role.own"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Podcaster"].exists)
        if let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: URL(fileURLWithPath: folder).appending(path: "edit_profile_2.png"))
        }
        app.buttons["editProfile.doneButton"].tap()
        XCTAssertTrue(app.staticTexts["Profile updated"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS 'Podcaster'")).firstMatch.waitForExistence(timeout: 5))
    }

    /// Edit Profile (9.1): a username typed must fit (2–24 of a–z 0–9 . _); Done saves name and username and says so.
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
        // The seeded profile is empty: its card offers "Set up your profile" where a filled one has Edit.
        app.buttons["profile.setUpButton"].tap()
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
        app.buttons["voiceSetup.audience.parents"].tap()
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
