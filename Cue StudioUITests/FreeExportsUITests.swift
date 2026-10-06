//
//  FreeExportsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The free exports running out (09): the line under Share counts them down, and with none left Share, Save and the share icon ask "Your video
/// is ready" before anything else; "Not now" keeps the take ready, the trial goes to the calm Pro.
@MainActor
final class FreeExportsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openTake(_ app: XCUIApplication) {
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(element(app, "review.exportNotice").waitForExistence(timeout: 5))
    }

    func testTheLineUnderShareCountsDownAndTurnsToTheLastOne() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestExportsLeft", "3"])
        openTake(app)
        XCTAssertTrue(element(app, "review.exportNotice").label.contains("3 OF 5 FREE EXPORTS LEFT"))
        XCTAssertTrue(app.buttons["review.goPro"].exists)
        app.terminate()

        let last = CueApp.launch(seeded: true, extraArguments: ["-uiTestExportsLeft", "1"])
        openTake(last)
        XCTAssertTrue(element(last, "review.exportNotice").label.contains("LAST FREE EXPORT"))
    }

    func testProSaysUnlimitedAndHasNoGoPro() {
        let app = CueApp.launch(seeded: true, pro: true)
        openTake(app)
        XCTAssertTrue(element(app, "review.exportNotice").label.contains("PRO · UNLIMITED EXPORTS"))
        XCTAssertFalse(app.buttons["review.goPro"].exists)
    }

    func testWithNoneLeftSaveAsksYourVideoIsReadyAndNotNowKeepsTheTakeReady() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestExportsLeft", "0"])
        openTake(app)
        XCTAssertTrue(element(app, "review.exportNotice").label.contains("0 OF 5 FREE EXPORTS LEFT"))
        app.buttons["review.saveButton"].tap()
        let notNow = app.buttons["exportReady.notNow"]
        XCTAssertTrue(notNow.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["exportReady.trial"].exists)
        XCTAssertTrue(app.buttons["exportReady.seePro"].exists)
        notNow.tap()
        // First: a toast stays 2.4 s, and the queries below each take a moment of their own.
        XCTAssertTrue(EditorApp.toastSays(app, "export with Pro anytime", timeout: 5))
        XCTAssertTrue(element(app, "review.exportNotice").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "review.exportNotice").label.contains("READY · EXPORT WITH PRO"))
    }

    func testStartingTheTrialFromTheSheetOpensTheCalmPro() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestExportsLeft", "0"])
        openTake(app)
        app.buttons["review.saveButton"].tap()
        let trial = app.buttons["exportReady.trial"]
        XCTAssertTrue(trial.waitForExistence(timeout: 5))
        trial.tap()
        XCTAssertTrue(app.buttons["paywall.closeButton"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.staticTexts["YOUR VIDEO IS READY"].exists)
        XCTAssertTrue(app.staticTexts["Keep sharing your universe."].exists)
    }

    /// The calm Pro keeps the plans and Restore, Terms and Privacy.
    func testTheCalmProOffersThePlansAndTheSmallPrint() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestExportsLeft", "0"])
        openTake(app)
        app.buttons["review.saveButton"].tap()
        app.buttons["exportReady.seePro"].tap()
        XCTAssertTrue(app.buttons["paywall.buyButton"].waitForExistence(timeout: 8))
        XCTAssertTrue(app.buttons["paywall.plan.annual"].exists && app.buttons["paywall.plan.monthly"].exists)
        XCTAssertTrue(app.buttons["Restore"].exists)
        app.buttons["paywall.privacyButton"].tap()
        XCTAssertTrue(app.navigationBars["Privacy & AI data"].waitForExistence(timeout: 5))
    }
}
