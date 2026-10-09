//
//  ShareToUITests.swift
//  Cue StudioUITests
//

import XCTest

/// "Share to universe" (8.1) from a take's review: Ready to travel, the networks, the queue one network at a time, "Posted on…?", the send-off, and the
/// "Continue posting" card of a queue that was left. The system share sheet is a stand-in with Complete and Cancel (`-uiTestFakeShareSheet`).
@MainActor
final class ShareToUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    // MARK: - Ready to travel and the networks

    func testShareToUniverseOpensReadyAndTheNetworksWithTheScriptsOneTicked() {
        let app = openShare()
        XCTAssertTrue(element(app, "ready.sheet").exists)
        for network in ["tiktok", "reels", "shorts", "youtube", "linkedin"] {
            XCTAssertTrue(element(app, "shareFlow.network.\(network)").exists, network)
        }
        XCTAssertTrue(element(app, "shareFlow.network.tiktok").isSelected)
        XCTAssertFalse(element(app, "shareFlow.network.reels").isSelected)
        XCTAssertTrue(app.buttons["shareFlow.start"].label.contains("Share to TikTok"))
        XCTAssertTrue(app.switches["shareFlow.saveToPhotos"].exists)
    }

    func testPickingNetworksChangesTheButtonAndNothingPickedAsksToPick() {
        let app = openShare()
        element(app, "shareFlow.network.reels").tap()
        element(app, "shareFlow.network.linkedin").tap()
        XCTAssertTrue(app.buttons["shareFlow.start"].label.contains("Share to 3 networks"))
        for network in ["reels", "linkedin", "tiktok"] { element(app, "shareFlow.network.\(network)").tap() }
        XCTAssertTrue(app.buttons["shareFlow.start"].label.contains("Pick a network"))
        XCTAssertFalse(app.buttons["shareFlow.start"].isEnabled)
    }

    func testFourKIsFree() {
        let app = openShare()
        app.buttons["shareFlow.options"].tap()
        let quality = app.segmentedControls["share.quality"]
        XCTAssertTrue(quality.waitForExistence(timeout: 5))
        quality.buttons["4K"].tap()
        XCTAssertTrue(quality.buttons["4K"].isSelected)
        XCTAssertFalse(app.buttons["paywall.closeButton"].exists)
    }

    func testClosingTheNetworksLeavesReadyWithItsThreeWaysOut() {
        let app = openShare()
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(app.buttons["ready.shareButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ready.saveButton"].exists)
        XCTAssertTrue(app.buttons["ready.shareIcon"].exists)
    }

    // MARK: - The queue

    func testTwoNetworksShowTheExplanationThenEachNetworksStep() {
        let app = openShare()
        element(app, "shareFlow.network.reels").tap()
        app.buttons["shareFlow.start"].tap()
        XCTAssertTrue(waitAllowingPhotos(for: app.staticTexts["Posting to 2 networks"]))
        app.buttons["shareFlow.explainerStart"].tap()
        XCTAssertTrue(app.staticTexts["Post to TikTok"].waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "shareFlow.position").label, "1 OF 2")
        XCTAssertTrue(app.buttons["shareFlow.send"].exists && app.buttons["shareFlow.editFirst"].exists && app.buttons["shareFlow.postLater"].exists)
        app.buttons["shareFlow.postLater"].tap()
        // Post later is a menu (a reminder or none): "No reminder" leaves the network for later, as the button did.
        XCTAssertTrue(app.buttons["shareFlow.noReminder"].waitForExistence(timeout: 5))
        app.buttons["shareFlow.noReminder"].tap()
        XCTAssertTrue(app.staticTexts["Post to Reels"].waitForExistence(timeout: 5))
        XCTAssertEqual(element(app, "shareFlow.position").label, "2 OF 2")
    }

    func testPostingLaterOnEveryNetworkSavesAndTheReviewOffersToPostLater() {
        let app = openShare()
        app.buttons["shareFlow.start"].tap()
        XCTAssertTrue(waitAllowingPhotos(for: app.buttons["shareFlow.postLater"]))
        app.buttons["shareFlow.postLater"].tap()
        // Post later is a menu (a reminder or none): "No reminder" leaves the network for later, as the button did.
        XCTAssertTrue(app.buttons["shareFlow.noReminder"].waitForExistence(timeout: 5))
        app.buttons["shareFlow.noReminder"].tap()
        XCTAssertTrue(app.staticTexts["Saved · continue anytime"].waitForExistence(timeout: 5))
        app.buttons["ready.closeButton"].tap()
        XCTAssertTrue(app.buttons["review.postLater"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["review.postLater"].label, "POST TO TIKTOK LATER")
    }

    func testPostLaterCanRemindTheCreatorTomorrow() {
        let app = openShare()
        app.buttons["shareFlow.start"].tap()
        XCTAssertTrue(waitAllowingPhotos(for: app.buttons["shareFlow.postLater"]))
        app.buttons["shareFlow.postLater"].tap()
        let tomorrow = app.buttons["shareFlow.remindTomorrow"]
        XCTAssertTrue(tomorrow.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["shareFlow.remindPick"].exists && app.buttons["shareFlow.noReminder"].exists)
        tomorrow.tap()
        XCTAssertTrue(app.buttons["ready.closeButton"].waitForExistence(timeout: 5))
        app.buttons["ready.closeButton"].tap()
        XCTAssertTrue(app.buttons["review.postLater"].waitForExistence(timeout: 5), "The network still waits for later")
        app.buttons["review.backButton"].tap()
        // The reminder is listed in Settings › Notifications, for that network.
        app.cueTabBar.buttons["Settings"].tap()
        let notifications = app.descendants(matching: .any)["settings.notifications"].firstMatch
        app.scroll(to: notifications)
        notifications.tap()
        let reminder = app.descendants(matching: .any)["notifications.reminder"].firstMatch
        XCTAssertTrue(reminder.waitForExistence(timeout: 5))
        XCTAssertTrue(reminder.label.contains("Post on TikTok"), reminder.label)
    }

    func testNotYetKeepsTheNetworkAndYesSendsItOff() {
        let app = openShare(animations: true)
        app.buttons["shareFlow.start"].tap()
        XCTAssertTrue(waitAllowingPhotos(for: app.buttons["shareFlow.send"]))
        app.buttons["shareFlow.send"].tap()
        XCTAssertTrue(app.buttons["debug.share.complete"].waitForExistence(timeout: 10))
        app.buttons["debug.share.complete"].tap()
        XCTAssertTrue(app.staticTexts["Posted on TikTok?"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Welcome back. Cue lights its planet once it’s live."].exists)
        app.buttons["shareFlow.notYet"].tap()
        XCTAssertTrue(app.buttons["shareFlow.send"].waitForExistence(timeout: 5), "back to the step: it can be sent again")
        app.buttons["shareFlow.send"].tap()
        // Each step waits for its screen: a tap that comes early lands on the step under it (Post later is a menu there).
        XCTAssertTrue(app.buttons["debug.share.complete"].waitForExistence(timeout: 10))
        app.buttons["debug.share.complete"].tap()
        XCTAssertTrue(app.buttons["shareFlow.live"].waitForExistence(timeout: 10))
        app.buttons["shareFlow.live"].tap()
        XCTAssertTrue(element(app, "sendoff.sheet").waitForExistence(timeout: 20))
        XCTAssertEqual(element(app, "sendoff.headline").label, "SHARED TO TIKTOK")
    }

    func testACancelledShareSheetGoesBackToTheStep() {
        let app = openShare(animations: true)
        app.buttons["shareFlow.start"].tap()
        XCTAssertTrue(waitAllowingPhotos(for: app.buttons["shareFlow.send"]))
        app.buttons["shareFlow.send"].tap()
        XCTAssertTrue(app.buttons["debug.share.cancel"].waitForExistence(timeout: 10))
        app.buttons["debug.share.cancel"].tap()
        XCTAssertTrue(app.buttons["shareFlow.send"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.staticTexts["Posted on TikTok?"].exists)
    }

    // MARK: - Continue posting

    func testALeftQueueShowsTheCardOnScriptsAndTakesAndTheCrossLeavesItForLater() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestShareQueue"])
        let card = element(app, "continuePosting.card")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts["CONTINUE POSTING · 1 OF 2"].exists)
        app.cueTabBar.buttons["Takes"].tap()
        XCTAssertTrue(element(app, "continuePosting.card").waitForExistence(timeout: 5))
        element(app, "continuePosting.close").tap()
        XCTAssertTrue(app.staticTexts["Saved · post when you’re ready"].waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "continuePosting.card").exists)
    }

    func testContinueOpensTheReviewAtTheNetworksStep() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestShareQueue"])
        XCTAssertTrue(element(app, "continuePosting.card").waitForExistence(timeout: 15))
        element(app, "continuePosting.continue").tap()
        XCTAssertTrue(app.staticTexts["Post to TikTok"].waitForExistence(timeout: 60))
        XCTAssertEqual(element(app, "shareFlow.position").label, "1 OF 2")
    }

    // MARK: - Helpers

    /// A take's review, "Share to universe" tapped: Ready to travel with the networks over it. A test that ends the share sheet asks for
    /// `animations`: the networks' sheet only comes back after the share sheet has animated away (`ShareFlow.settle`); without
    /// animations SwiftUI never presents it again.
    private func openShare(animations: Bool = false) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: true, animations: animations, extraArguments: ["-uiTestFakeShareSheet"])
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let share = app.buttons["review.shareButton"]
        XCTAssertTrue(share.waitForExistence(timeout: 10))
        share.tap()
        XCTAssertTrue(element(app, "shareFlow.start").waitForExistence(timeout: 120))
        return app
    }
}
