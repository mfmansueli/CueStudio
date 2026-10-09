//
//  NotificationsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Notifications from the creator's side: the Settings page (tools and news start off, iOS's answer said plainly), a reminder set from a
/// script, and what a tapped notification opens — the script, a tool's introduction before the tool, a short explanation when the script
/// is gone, nothing for a payload Cue can't read, and one opening for a tap the system repeats. The permission is an in-memory stand-in
/// (`-uiTestNotificationAuth`), so no system prompt ever shows; a tap is simulated at launch (`-uiTestNotificationTap`).
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
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        let row = element(app, "settings.notifications")
        app.scroll(to: row)
        row.tap()
        XCTAssertTrue(element(app, "notifications.screen").waitForExistence(timeout: 5))
    }

    private func isOn(_ toggle: XCUIElement) -> Bool {
        (toggle.value as? String) == "1"
    }

    // MARK: - Settings

    func testToolsAndNewsStartOffAndCueSaysItWillAskWhenNeeded() {
        let app = CueApp.launch(seeded: true)
        openNotificationSettings(app)
        XCTAssertTrue(element(app, "notifications.notAsked").exists)
        XCTAssertTrue(isOn(app.switches["notifications.category.reminders"]))
        XCTAssertTrue(isOn(app.switches["notifications.category.projects"]))
        XCTAssertFalse(isOn(app.switches["notifications.category.discovery"]))
        XCTAssertFalse(isOn(app.switches["notifications.category.whatsNew"]))
        XCTAssertTrue(element(app, "notifications.noReminders").exists)
    }

    func testWithNotificationsOffTheyAreSaidAndSettingsIsTheCreatorsToOpen() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationAuth", "denied"])
        openNotificationSettings(app)
        XCTAssertTrue(element(app, "notifications.denied").exists)
        XCTAssertTrue(app.buttons["notifications.openSettings"].exists)
    }

    // MARK: - Reminders

    func testAReminderFromAScriptIsSetAndListed() {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        app.buttons["page.menuButton"].tap()
        let remind = app.buttons["page.remindMe"]
        XCTAssertTrue(remind.waitForExistence(timeout: 5))
        remind.tap()
        let tomorrow = app.buttons["reminder.tomorrow"]
        XCTAssertTrue(tomorrow.waitForExistence(timeout: 5))
        tomorrow.tap()
        let set = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Reminder set'")).firstMatch
        XCTAssertTrue(set.waitForExistence(timeout: 5), "Set is only said once the system took it")
        app.pageBackButton.tap()
        openNotificationSettings(app)
        XCTAssertTrue(element(app, "notifications.reminder").waitForExistence(timeout: 5))
    }

    func testWithNotificationsOffAReminderIsKeptInCue() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationAuth", "denied"])
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        app.buttons["page.menuButton"].tap()
        app.buttons["page.remindMe"].tap()
        app.buttons["reminder.tomorrow"].tap()
        XCTAssertTrue(app.staticTexts["Saved in Cue · notifications are off"].waitForExistence(timeout: 5))
    }

    // MARK: - Opening a notification

    func testANotificationOpensItsScript() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "script"])
        XCTAssertTrue(app.pageBackButton.waitForExistence(timeout: 15), "The script's page opens")
        XCTAssertTrue(app.buttons["page.menuButton"].exists)
    }

    func testAToolsNotificationIntroducesTheToolAndNotNowOpensNothing() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "cleanUp"])
        let sheet = element(app, "featureIntro.sheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["featureIntro.try"].exists && app.buttons["featureIntro.decline"].exists)
        XCTAssertTrue(element(app, "featureIntro.note").exists, "What the tool uses is said before Try it")
        app.buttons["featureIntro.notNow"].tap()
        XCTAssertFalse(sheet.waitForExistence(timeout: 2))
        XCTAssertFalse(app.buttons["review.shareButton"].exists, "Not now opens nothing")
    }

    func testTryItOpensCleanUpOnThatTake() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestNotificationTap", "cleanUp"])
        let tryIt = app.buttons["featureIntro.try"]
        XCTAssertTrue(tryIt.waitForExistence(timeout: 15))
        tryIt.tap()
        let pauses = element(app, "edit.pauses.threshold")
        XCTAssertTrue(pauses.waitForExistence(timeout: 30), "Quick edit opens on Clean Up")
    }

    func testANotificationAboutADeletedScriptSaysSo() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "deletedScript"])
        XCTAssertTrue(app.staticTexts["That script is no longer in Cue"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.pageBackButton.exists)
    }

    func testAPayloadCueCantReadOpensNothing() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "invalid"])
        XCTAssertTrue(app.buttons["scripts.selectButton"].waitForExistence(timeout: 15))
        XCTAssertFalse(app.pageBackButton.exists)
        XCTAssertFalse(element(app, "featureIntro.sheet").exists)
    }

    func testATapTheSystemRepeatsOpensOnce() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestNotificationTap", "duplicate"])
        XCTAssertTrue(element(app, "notifications.screen").waitForExistence(timeout: 15))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "No second Notifications page on top")
    }
}
