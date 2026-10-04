//
//  AppearanceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Cue's screens in the light appearance, and Settings › Appearance. The contrast of every pair is
/// measured by `PaletteContrastTests`; here the screens open and read in light, and the screenshots
/// are kept for a visual check.
@MainActor
final class AppearanceUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func capture(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func tab(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.tabBars.buttons[label]
    }

    func testTheMainScreensOpenInLight() {
        let app = CueApp.launch(seeded: true, appearance: "light")
        XCTAssertTrue(tab(app, "Scripts").waitForExistence(timeout: 15))
        capture(app, "Scripts · light")
        tab(app, "Takes").tap()
        XCTAssertTrue(app.navigationBars["Takes"].waitForExistence(timeout: 5))
        capture(app, "Takes · light")
        tab(app, "Profile").tap()
        XCTAssertTrue(app.navigationBars["Profile"].waitForExistence(timeout: 5))
        capture(app, "Profile · light")
        tab(app, "Settings").tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        capture(app, "Settings · light")
    }

    func testAScriptOpensInLight() {
        let app = CueApp.launch(seeded: true, appearance: "light")
        XCTAssertTrue(tab(app, "Scripts").waitForExistence(timeout: 15))
        let first = app.staticTexts["3 morning habits that changed my life"]
        XCTAssertTrue(first.waitForExistence(timeout: 5))
        first.tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 5))
        capture(app, "Script · light")
    }

    func testAppearanceIsPickedInSettings() {
        let app = CueApp.launch(seeded: true, appearance: "dark")
        tab(app, "Settings").tap()
        let light = app.buttons["settings.appearance.light"]
        XCTAssertTrue(light.waitForExistence(timeout: 5))
        light.tap()
        XCTAssertTrue(light.isSelected)
        XCTAssertTrue(tab(app, "Settings").waitForExistence(timeout: 5))
        capture(app, "Settings · switched to light")
    }
}
