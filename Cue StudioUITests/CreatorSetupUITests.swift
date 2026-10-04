//
//  CreatorSetupUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Settings › Recording, Prompter and Remote: defaults that stick, reset, remote pairing, and the
/// recommendation the recording screen offers when a platform wants something else.
@MainActor
final class CreatorSetupUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testChoicesStayAfterLeavingCreatorSetup() {
        let app = CueApp.launch(seeded: true)
        openCreatorSetup(app)
        let fourK = app.buttons["creatorSetup.quality.4K"]
        XCTAssertTrue(fourK.waitForExistence(timeout: 5))
        fourK.tap()
        XCTAssertTrue(fourK.isSelected)
        app.navigationBars.buttons.firstMatch.tap()
        openCreatorSetup(app, page: "prompter")
        let large = app.buttons["creatorSetup.textSize.large"]
        XCTAssertTrue(large.waitForExistence(timeout: 5))
        large.tap()
        XCTAssertTrue(large.isSelected)

        // The card on Settings says what was chosen, and both pages remember it.
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["settings.setup.quality"].label.contains("4K"))
        openCreatorSetup(app)
        XCTAssertTrue(app.buttons["creatorSetup.quality.4K"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["creatorSetup.quality.4K"].isSelected)
        app.navigationBars.buttons.firstMatch.tap()
        openCreatorSetup(app, page: "prompter")
        XCTAssertTrue(app.buttons["creatorSetup.textSize.large"].isSelected)
    }

    func testResetAsksBeforeRestoringTheDefaults() {
        let app = CueApp.launch(seeded: true)
        openCreatorSetup(app)
        app.buttons["creatorSetup.quality.4K"].tap()
        app.navigationBars.buttons.firstMatch.tap()
        let reset = app.buttons["creatorSetup.resetButton"]
        scroll(app, to: reset)
        reset.tap()
        // The dialog's button, not the one on the page.
        let confirm = app.buttons
            .matching(NSPredicate(format: "label == %@ AND identifier != %@", "Reset Creator Setup", "creatorSetup.resetButton"))
            .firstMatch
        XCTAssertTrue(confirm.waitForExistence(timeout: 5))
        confirm.tap()
        scrollUp(app, to: app.buttons["settings.recordingTile"])
        openCreatorSetup(app)
        XCTAssertTrue(app.buttons["creatorSetup.quality.1080p"].isSelected)
    }

    func testConnectADeviceShowsACodeThenTheConnection() {
        let app = CueApp.launch(seeded: true, remoteConnects: true)
        openCreatorSetup(app, page: "remote")
        XCTAssertTrue(app.descendants(matching: .any)["remote.statusHero"].waitForExistence(timeout: 5))
        let connect = app.buttons["remote.connectButton"]
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
        connect.tap()
        XCTAssertTrue(app.descendants(matching: .any)["remote.qrCode"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["remote.code"].exists)
        XCTAssertTrue(app.staticTexts["Remote Connected"].waitForExistence(timeout: 5))
        app.buttons["remote.disconnectButton"].tap()
        XCTAssertTrue(connect.waitForExistence(timeout: 5))
    }

    func testTheRecorderOffersThePlatformSetupWithoutChangingYours() {
        let app = CueApp.launch(seeded: true)
        openCreatorSetup(app)
        app.buttons["creatorSetup.quality.4K"].tap()
        // Back to Settings: a tab keeps its screen, and the end of the test opens Creator Setup again.
        app.navigationBars["Recording"].buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["settings.recordingTile"].waitForExistence(timeout: 5))

        // "3 morning habits" is for TikTok, which recommends 1080p.
        app.cueTabBar.buttons["Scripts"].tap()
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        let use = app.buttons["prompter.useRecommendedButton"]
        XCTAssertTrue(use.waitForExistence(timeout: 5))
        XCTAssertEqual(use.label, "Use 1080p")
        XCTAssertEqual(app.buttons["prompter.keepSetupButton"].label, "Keep 4K")
        use.tap()
        XCTAssertFalse(use.waitForExistence(timeout: 2))
        let pill = app.buttons["prompter.setupButton"]
        XCTAssertTrue((pill.value as? String)?.contains("TikTok setup") == true)
        pill.tap()
        let back = app.buttons["setup.backToMySetupButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 5))
        // The sheet has to be gone before Close reaches the prompter. (A swipe from the middle of
        // the screen starts above this short sheet, on the prompter.)
        app.buttons["sheet.closeButton"].tap()
        XCTAssertTrue(back.waitForNonExistence(timeout: 5))
        app.buttons["prompter.closeButton"].tap()

        // The Creator Setup is still 4K.
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.waitForExistence(timeout: 5))
        settings.tap()
        openCreatorSetup(app)
        XCTAssertTrue(app.buttons["creatorSetup.quality.4K"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["creatorSetup.quality.4K"].isSelected)
    }

    func testSettingsDisplayUsesTheSharedEditorAndKeepsLocalRecordingEditsSeparate() {
        let app = CueApp.launch(seeded: true)
        openCreatorSetup(app, page: "prompter")
        let display = app.buttons["creatorSetup.displayButton"]
        scroll(app, to: display)
        display.tap()
        XCTAssertTrue(app.sliders["display.readingWidth"].waitForExistence(timeout: 5))
        app.sliders["display.readingWidth"].adjust(toNormalizedSliderPosition: 0.4)
        let savedWidth = app.sliders["display.readingWidth"].value as? String
        let layout = XCTAttachment(screenshot: app.screenshot())
        layout.name = "Creator Setup · Display layout"
        layout.lifetime = .keepAlways
        add(layout)
        let advanced = app.buttons["display.advancedButton"]
        scroll(app, to: advanced)
        advanced.tap()
        let serif = app.buttons["display.font.serif"]
        scroll(app, to: serif)
        serif.tap()
        XCTAssertTrue(serif.isSelected)
        let appearance = XCTAttachment(screenshot: app.screenshot())
        appearance.name = "Creator Setup · Display appearance"
        appearance.lifetime = .keepAlways
        add(appearance)
        XCTAssertFalse(app.alerts.firstMatch.exists)
        app.buttons["display.doneButton"].tap()
        app.navigationBars.buttons.firstMatch.tap()

        app.cueTabBar.buttons["Scripts"].tap()
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        let aa = app.buttons["prompter.displayButton"]
        XCTAssertTrue(aa.waitForExistence(timeout: 5))
        aa.tap()
        XCTAssertTrue(app.sliders["display.readingWidth"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.sliders["display.readingWidth"].value as? String, savedWidth)
        scroll(app, to: advanced)
        advanced.tap()
        scroll(app, to: serif)
        XCTAssertTrue(serif.isSelected)
        let rounded = app.buttons["display.font.rounded"]
        rounded.tap()
        XCTAssertTrue(rounded.isSelected)
        app.buttons["display.doneButton"].tap()
        app.buttons["prompter.closeButton"].tap()

        openCreatorSetup(app, page: "prompter")
        scroll(app, to: display)
        display.tap()
        scroll(app, to: advanced)
        advanced.tap()
        scroll(app, to: serif)
        XCTAssertTrue(serif.isSelected)
        XCTAssertFalse(rounded.isSelected)
    }

    // MARK: - Helpers

    /// Settings, then one of the three pages under "Your setup" (recording by default).
    private func openCreatorSetup(_ app: XCUIApplication, page: String = "recording") {
        let tab = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let tile = app.buttons["settings.\(page)Tile"]
        scroll(app, to: tile)
        tile.tap()
        XCTAssertTrue(app.cueTabBar.buttons["Settings"].isSelected)
    }

    private func scroll(_ app: XCUIApplication, to element: XCUIElement) {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            let display = app.scrollViews.containing(.button, identifier: "display.advancedButton").firstMatch
            if display.exists {
                display.swipeUp()
            } else {
                app.swipeUp()
            }
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }

    private func scrollUp(_ app: XCUIApplication, to element: XCUIElement) {
        for _ in 0..<8 where !(element.exists && element.isHittable) {
            app.swipeDown()
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5))
    }
}
