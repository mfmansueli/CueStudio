//
//  QuickEditSoundUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Sound and background in Quick edit, on a small real video: the Voice levels, the Music tool's
/// rights note, and a background blurred, keyed and put back.
@MainActor
final class QuickEditSoundUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testAudioHasVoiceMusicAndVoiceOver() {
        let app = openQuickEdit()
        app.buttons["edit.category.audio"].tap()
        XCTAssertTrue(app.buttons["edit.tool.audio"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["edit.tool.music"].exists)
        XCTAssertTrue(app.buttons["edit.tool.voiceOver"].exists)

        app.buttons["edit.tool.audio"].tap()
        let enhance = element(app, "edit.enhanceVoice")
        XCTAssertTrue(enhance.waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "edit.reduceNoise").exists)
        enhance.buttons["Strong"].tap()
        XCTAssertTrue(enhance.buttons["Strong"].isSelected)
        XCTAssertTrue(element(app, "edit.compareOriginal").isEnabled)

        app.buttons["edit.tool.music"].tap()
        XCTAssertTrue(app.buttons["edit.addMusicButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "edit.musicRightsNote").exists)
    }

    func testABackgroundBlurAppliesToTheTakeAndGoesBack() {
        let app = openQuickEdit()
        app.buttons["edit.category.adjust"].tap()
        let tool = app.buttons["edit.tool.background"]
        XCTAssertTrue(tool.waitForExistence(timeout: 5))
        tool.tap()
        XCTAssertTrue(app.staticTexts["This take"].waitForExistence(timeout: 5))
        let blur = app.buttons["edit.background.blur"]
        XCTAssertTrue(blur.exists)
        blur.tap()
        XCTAssertTrue(blur.isSelected)
        XCTAssertTrue(element(app, "edit.backgroundBlur").waitForExistence(timeout: 5))
        // The color key has its own controls.
        element(app, "edit.backgroundCutout").buttons["Color key"].tap()
        XCTAssertTrue(element(app, "edit.keyTolerance").waitForExistence(timeout: 5))
        let original = app.buttons["edit.background.original"]
        original.tap()
        XCTAssertTrue(original.isSelected)
        XCTAssertFalse(element(app, "edit.backgroundBlur").exists)
    }

    private func openQuickEdit() -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: true)
        let tab = app.tabBars.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let time = app.staticTexts["edit.timeLabel"]
        let ready = NSPredicate(format: "value == %@", "00:00.00 / 01:02.00")
        XCTAssertEqual(XCTWaiter.wait(for: [expectation(for: ready, evaluatedWith: time)], timeout: 10), .completed)
        return app
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }
}
