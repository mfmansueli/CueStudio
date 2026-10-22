//
//  NotificationsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Notifications from the creator's side: the Settings page (iOS's answer as a switch, whose first yes lights the three switches below
/// together), a reminder set from a script, and what a tapped notification opens — the script, a tool's introduction before the tool, a
/// short explanation when the script is gone, nothing for a payload Cue can't read, and one opening for a tap the system repeats. The
/// permission is an in-memory stand-in (`-uiTestNotificationAuth`), so no system prompt ever shows; a tap is simulated at launch
/// (`-uiTestNotificationTap`).
@MainActor
final class NotificationsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openNotificationSettings(_ app: XCUIApplication) {
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.exists(within: 15))
        settings.tap()
        let row = element(app, "settings.notifications")
        app.scroll(to: row)
        row.tap()
        XCTAssertTrue(element(app, "notifications.screen").exists(within: 5))
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    /// A two-line switch is flipped on its control, not its label (a tap in the middle hits the words).
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    // MARK: - Settings

    private func cardTitle(_ app: XCUIApplication) -> XCUIElement {
        app.staticTexts["notifications.permission.title"]
    }

    /// Never asked: the switch on top says notifications are off; the three below wait, off, and nothing else asks for a choice.
    func testNotificationsSayTheyAreOffAndTheSwitchesWait() {
        let app = CueApp.launch(seeded: true)
        openNotificationSettings(app)
        XCTAssertEqual(cardTitle(app).label, "Notifications are off")
        XCTAssertFalse(isOn(app.switches["notifications.permission"]))
        for group in ["finish", "routine", "news"] {
            let toggle = app.switches["notifications.group.\(group)"]
            XCTAssertTrue(toggle.exists, group)
            XCTAssertFalse(isOn(toggle), "\(group) waits until iOS allows Cue")
        }
        XCTAssertTrue(element(app, "notifications.noReminders").exists)
        XCTAssertFalse(app.switches["Show titles in previews"].exists, "The page is short: no titles, quiet hours or pause")
    }

    /// The switch on top: iOS asks once and its yes turns everything on together; the routine opens its days.
    func testTheSwitchAsksIOSAndTurnsEverythingOnTogether() {
        let app = CueApp.launch(seeded: true)
        openNotificationSettings(app)
        flip(app.switches["notifications.permission"])
        for group in ["finish", "routine", "news"] {
            let lit = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: app.switches["notifications.group.\(group)"])
            XCTAssertEqual(XCTWaiter.wait(for: [lit], timeout: 5), .completed, "\(group) lights with the yes")
        }
        XCTAssertTrue(element(app, "notifications.routine.day.2").exists(within: 3), "The routine opens on its usual days")
        XCTAssertTrue(isOn(app.switches["notifications.permission"]))
        XCTAssertEqual(cardTitle(app).label, "Notifications are on")
        flip(app.switches["notifications.group.news"])
        XCTAssertFalse(isOn(app.switches["notifications.group.news"]), "Each switch is the creator's after that")
    }

    func testWithNotificationsOffInIOSTheSwitchOpensIOSSettings() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationAuth", "denied"])
        openNotificationSettings(app)
        XCTAssertEqual(cardTitle(app).label, "Notifications are off in iOS")
        flip(app.switches["notifications.permission"])
        let settings = XCUIApplication(bundleIdentifier: "com.apple.Preferences")
        XCTAssertTrue(settings.wait(for: .runningForeground, timeout: 10), "Only iOS Settings can allow Cue again")
        app.activate()
        XCTAssertEqual(cardTitle(app).label, "Notifications are off in iOS", "Nothing changed in iOS")
        XCTAssertFalse(isOn(app.switches["notifications.permission"]))
    }

    // MARK: - The invitation

    /// Opens the recorder from a script's page and closes it: the moment after a session, when the creator has recordings to finish.
    private func recordAndClose(_ app: XCUIApplication) {
        app.openScriptPage(titled: "Oat & Co. — sponsored read")
        let record = app.buttons["detail.recordButton"]
        XCTAssertTrue(record.exists(within: 5))
        record.tap()
        let close = app.buttons["prompter.closeButton"]
        XCTAssertTrue(close.exists(within: 15))
        close.tap()
    }

    func testAfterASessionCueInvitesAndAllowIsWhatAsksIOS() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationInvite"])
        recordAndClose(app)
        let sheet = element(app, "notificationInvite.sheet")
        XCTAssertTrue(sheet.exists(within: 10), "The invitation comes after the recorder closes")
        XCTAssertTrue(app.staticTexts["Want Cue to remind you to finish this video?"].exists)
        app.buttons["notificationInvite.allow"].tap()
        XCTAssertFalse(sheet.exists(within: 2))
        app.pageBackButton.tap()
        openNotificationSettings(app)
        XCTAssertTrue(isOn(app.switches["notifications.permission"]), "Allow brought up iOS's question, and the in-memory iOS said yes")
        XCTAssertTrue(isOn(app.switches["notifications.group.finish"]))
    }

    func testNotNowKeepsIOSsQuestionForLater() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationInvite"])
        recordAndClose(app)
        let notNow = app.buttons["notificationInvite.notNow"]
        XCTAssertTrue(notNow.exists(within: 10))
        notNow.tap()
        XCTAssertFalse(element(app, "notificationInvite.sheet").exists(within: 2))
        app.pageBackButton.tap()
        openNotificationSettings(app)
        XCTAssertEqual(cardTitle(app).label, "Notifications are off", "iOS wasn't asked")
        XCTAssertFalse(isOn(app.switches["notifications.permission"]))
    }

    // MARK: - Reminders

    func testAReminderFromAScriptIsSetAndListed() {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        app.buttons["page.menuButton"].tap()
        let remind = app.buttons["page.remindMe"]
        XCTAssertTrue(remind.exists(within: 5))
        remind.tap()
        let tomorrow = app.buttons["reminder.tomorrow"]
        XCTAssertTrue(tomorrow.exists(within: 5))
        tomorrow.tap()
        let set = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Reminder set'")).firstMatch
        XCTAssertTrue(set.exists(within: 5), "Set is only said once the system took it")
        app.pageBackButton.tap()
        openNotificationSettings(app)
        XCTAssertTrue(element(app, "notifications.reminder").exists(within: 5))
    }

    func testWithNotificationsOffAReminderIsKeptInCue() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationAuth", "denied"])
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        app.buttons["page.menuButton"].tap()
        app.buttons["page.remindMe"].tap()
        app.buttons["reminder.tomorrow"].tap()
        XCTAssertTrue(app.staticTexts["Saved in Cue · notifications are off"].exists(within: 5))
    }

    // MARK: - Opening a notification

    func testANotificationOpensItsScript() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "script"])
        XCTAssertTrue(app.pageBackButton.exists(within: 15), "The script's page opens")
        XCTAssertTrue(app.buttons["page.menuButton"].exists)
    }

    func testAToolsNotificationIntroducesTheToolAndNotNowOpensNothing() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "cleanUp"])
        let sheet = element(app, "featureIntro.sheet")
        XCTAssertTrue(sheet.exists(within: 15))
        XCTAssertTrue(app.buttons["featureIntro.try"].exists && app.buttons["featureIntro.decline"].exists)
        XCTAssertTrue(element(app, "featureIntro.note").exists, "What the tool uses is said before Try it")
        app.buttons["featureIntro.notNow"].tap()
        XCTAssertFalse(sheet.exists(within: 2))
        XCTAssertFalse(app.buttons["review.shareButton"].exists, "Not now opens nothing")
    }

    func testTryItOpensCleanUpOnThatTake() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestNotificationTap", "cleanUp"])
        let tryIt = app.buttons["featureIntro.try"]
        XCTAssertTrue(tryIt.exists(within: 15))
        tryIt.tap()
        XCTAssertTrue(element(app, "edit.panel.pauses").exists(within: 30), "Quick edit opens on Clean Up")
        XCTAssertTrue(app.buttons["edit.pauses.threshold.minus"].exists)
    }

    func testANotificationAboutADeletedScriptSaysSo() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "deletedScript"])
        XCTAssertTrue(app.staticTexts["That script is no longer in Cue"].exists(within: 15))
        XCTAssertFalse(app.pageBackButton.exists)
    }

    func testAPayloadCueCantReadOpensNothing() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "invalid"])
        XCTAssertTrue(app.buttons["scripts.selectButton"].exists(within: 15))
        XCTAssertFalse(app.pageBackButton.exists)
        XCTAssertFalse(element(app, "featureIntro.sheet").exists)
    }

    func testATapTheSystemRepeatsOpensOnce() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "duplicate"])
        XCTAssertTrue(element(app, "notifications.screen").exists(within: 15))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists(within: 5), "No second Notifications page on top")
    }
}
