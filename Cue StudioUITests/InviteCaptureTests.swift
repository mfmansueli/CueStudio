//
//  InviteCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// Pictures of the invites (DESIGN_PROJECT §60) with their accessibility hierarchy, for the owner and for `tools/contrast/audit.py`: the sheet
/// (free and Pro with Ultra AI, before and after friends), Profile's row, "Ready to travel" with one free export left and none, and "Your
/// video is ready". Opt in with `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>` (and `TEST_RUNNER_CUE_AUDIT_SIZE=<content size>` for a text size, on any
/// simulator `CUE_SIMULATOR` names); nothing is asserted beyond each screen opening.
@MainActor
final class InviteCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static var size: String? { ProcessInfo.processInfo.environment["CUE_AUDIT_SIZE"] }

    private func shot(_ app: XCUIApplication, _ name: String, wait: UInt32 = 1) throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if wait > 0 { sleep(wait) }
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
        try app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func profile(_ app: XCUIApplication) {
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let row = app.buttons["profile.inviteRow"]
        XCTAssertTrue(row.exists(within: 5))
        app.scroll(to: row)
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

    private func ready(_ app: XCUIApplication) {
        app.buttons["review.shareButton"].tap()
        XCTAssertTrue(element(app, "ready.sheet").exists(within: 30))
        let close = app.buttons["sheet.closeButton"].firstMatch
        XCTAssertTrue(close.exists(within: 8))
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5))
    }

    func testTheSheetAndProfile() throws {
        let app = CueApp.launch(seeded: true, contentSize: Self.size, extraArguments: ["-uiTestReferral"])
        profile(app)
        try shot(app, "i01_profile-row")
        app.buttons["profile.inviteRow"].tap()
        XCTAssertTrue(app.buttons["invite.copyButton"].exists(within: 8))
        try shot(app, "i02_sheet-new", wait: 2)
        app.buttons["invite.copyButton"].tap()
        try shot(app, "i02b_sheet-copied", wait: 0)
        let row = app.buttons["invite.friendCodeRow"]
        app.scroll(to: row)
        row.tap()
        let field = app.textFields["invite.codeField"]
        XCTAssertTrue(field.exists(within: 3))
        field.typeText("ABCDEF")
        app.buttons["invite.joinButton"].tap()
        XCTAssertTrue(app.staticTexts["No one has this code. Check it with your friend."].exists(within: 5))
        try shot(app, "i03_sheet-unknown-code")
        app.terminate()

        let friends = CueApp.launch(
            seeded: true, contentSize: Self.size, extraArguments: ["-uiTestReferral", "-uiTestReferralFriends", "5", "-uiTestExportsLeft", "1"]
        )
        profile(friends)
        friends.buttons["profile.inviteRow"].tap()
        XCTAssertTrue(friends.buttons["invite.copyButton"].exists(within: 8))
        try shot(friends, "i04_sheet-five-friends", wait: 3)
        friends.buttons["invite.doneButton"].tap()
        try shot(friends, "i05_profile-five-friends")
    }

    func testTheSheetOnProWithUltra() throws {
        let app = CueApp.launch(
            seeded: true, pro: true, contentSize: Self.size, extraArguments: ["-uiTestReferral", "-uiTestReferralFriends", "1", "-uiTestUltra"]
        )
        profile(app)
        app.buttons["profile.inviteRow"].tap()
        XCTAssertTrue(app.buttons["invite.copyButton"].exists(within: 8))
        try shot(app, "i06_sheet-pro", wait: 3)
    }

    func testTheMomentsAfterAnExport() throws {
        let last = CueApp.launch(seeded: true, sampleVideo: true, contentSize: Self.size, extraArguments: ["-uiTestReferral", "-uiTestExportsLeft", "1"])
        openTake(last)
        ready(last)
        try shot(last, "i07_ready-one-left")
        last.terminate()

        let none = CueApp.launch(seeded: true, sampleVideo: true, contentSize: Self.size, extraArguments: ["-uiTestReferral", "-uiTestExportsLeft", "0"])
        openTake(none)
        none.buttons["review.saveButton"].tap()
        XCTAssertTrue(none.buttons["exportReady.invite"].exists(within: 5))
        try shot(none, "i08_export-ready")
        none.terminate()

        let first = CueApp.launch(seeded: true, sampleVideo: true, contentSize: Self.size, extraArguments: ["-uiTestReferral"])
        openTake(first)
        ready(first)
        try shot(first, "i09_ready-first-export")
        first.buttons["ready.friendCode"].tap()
        XCTAssertTrue(first.textFields["invite.codeField"].exists(within: 8))
        try shot(first, "i10_sheet-friend-code")
    }
}
