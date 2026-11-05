//
//  InviteFriendsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Invites (DESIGN_PROJECT §60), with the stub server (`-uiTestReferral`: the creator's code K7M2QX, a friend's code P4WHNB): Profile's row
/// opens the code (a tap copies it) and what friends earned, which the free exports count; a friend opens "Have a friend's code?" and types
/// one before their first export; "Ready to travel"
/// offers an invite with one free export left and Cue Pro first with none; "Your video is ready" offers it under Cue Pro.
@MainActor
final class InviteFriendsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openInvites(friends: Int = 0, extra: [String] = []) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestReferral", "-uiTestReferralFriends", "\(friends)"] + extra)
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let row = app.buttons["profile.inviteRow"]
        XCTAssertTrue(row.exists(within: 5))
        app.scroll(to: row)
        row.tap()
        XCTAssertTrue(app.buttons["invite.copyButton"].exists(within: 8))
        return app
    }

    private func openTake(_ app: XCUIApplication) {
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.exists(within: 5))
        row.tap()
        XCTAssertTrue(element(app, "review.exportNotice").exists(within: 5))
    }

    /// Share from the review opens "Ready to travel" with "Share to universe" (the networks) on top: it goes down first.
    private func closePosting(_ app: XCUIApplication) {
        let close = app.buttons["sheet.closeButton"].firstMatch
        XCTAssertTrue(close.exists(within: 8))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
    }

    func testProfileOpensTheCodeAndWhatFriendsEarnedWhichTheFreeExportsCount() {
        let app = openInvites(friends: 2)
        let code = app.buttons["invite.copyButton"]
        XCTAssertTrue(code.label.contains("K7M2QX"), code.label)
        XCTAssertTrue(element(app, "invite.progress").label.contains("2 of 5 friends · +6 exports"))
        XCTAssertTrue(EditorApp.toastSays(app, "+6 exports", timeout: 5))
        code.tap()
        XCTAssertTrue(code.matches(NSPredicate(format: "label CONTAINS 'Copied'"), within: 3), code.label)
        XCTAssertTrue(app.buttons["invite.shareButton"].exists)
        app.buttons["invite.doneButton"].tap()
        // The plan card counts the 3 free exports and the 6 two friends earned.
        let plan = app.buttons["profile.upgradeButton"]
        XCTAssertTrue(plan.exists(within: 5))
        XCTAssertTrue(plan.label.contains("9 OF 9 EXPORTS LEFT"), plan.label)
        XCTAssertTrue(app.buttons["profile.inviteRow"].label.contains("2 of 5 friends"))
    }

    func testAFriendTypesACodeOnceBeforeTheirFirstExport() {
        let app = openInvites()
        XCTAssertFalse(app.textFields["invite.codeField"].exists)
        let row = app.buttons["invite.friendCodeRow"]
        app.scroll(to: row)
        row.tap()
        let field = app.textFields["invite.codeField"]
        XCTAssertTrue(field.exists(within: 3))
        field.typeText("abcdef")
        app.buttons["invite.joinButton"].tap()
        XCTAssertTrue(app.staticTexts["No one has this code. Check it with your friend."].exists(within: 5))
        field.tap()
        field.typeText(XCUIKeyboardKey.delete.rawValue.repeated(6) + "p4w-hnb")
        app.buttons["invite.joinButton"].tap()
        XCTAssertTrue(element(app, "invite.joined").exists(within: 5))
        XCTAssertFalse(app.textFields["invite.codeField"].exists)
    }

    func testWithOneFreeExportLeftReadyToTravelOffersAnInvite() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestReferral", "-uiTestExportsLeft", "1"])
        openTake(app)
        app.buttons["review.shareButton"].tap()
        XCTAssertTrue(element(app, "ready.sheet").exists(within: 30), "Ready to travel never opened")
        closePosting(app)
        let invite = app.buttons["ready.inviteButton"]
        XCTAssertTrue(invite.exists(within: 5))
        XCTAssertFalse(app.buttons["ready.proButton"].exists)
        invite.tap()
        XCTAssertTrue(app.buttons["invite.copyButton"].exists(within: 8))
    }

    func testWithNoneLeftYourVideoIsReadyOffersTheInviteUnderCuePro() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestReferral", "-uiTestExportsLeft", "0"])
        openTake(app)
        app.buttons["review.saveButton"].tap()
        let invite = app.buttons["exportReady.invite"]
        XCTAssertTrue(invite.exists(within: 5))
        XCTAssertTrue(app.buttons["exportReady.pro"].exists)
        invite.tap()
        XCTAssertTrue(app.buttons["invite.copyButton"].exists(within: 8))
    }

    func testBeforeTheFirstExportReadyToTravelAsksForAFriendsCode() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestReferral"])
        openTake(app)
        app.buttons["review.shareButton"].tap()
        XCTAssertTrue(element(app, "ready.sheet").exists(within: 30), "Ready to travel never opened")
        closePosting(app)
        XCTAssertFalse(element(app, "ready.inviteCard").exists)
        let friendCode = app.buttons["ready.friendCode"]
        XCTAssertTrue(friendCode.exists(within: 5))
        friendCode.tap()
        XCTAssertTrue(app.textFields["invite.codeField"].exists(within: 8))
    }

    /// Without Cue's server (no Firebase, or a UI test without the stub) nothing about invites shows.
    func testWithoutTheServerNoInviteIsOffered() {
        let app = CueApp.launch(seeded: true)
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        XCTAssertTrue(app.buttons["profile.upgradeButton"].exists(within: 5))
        XCTAssertFalse(app.buttons["profile.inviteRow"].exists)
    }
}

private extension String {
    func repeated(_ times: Int) -> String { String(repeating: self, count: times) }
}
