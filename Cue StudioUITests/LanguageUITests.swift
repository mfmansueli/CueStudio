//
//  LanguageUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Profile › Settings › Language & Region: the interface, Voice Following and scripts each keep
/// their own language. (In-memory launches never keep the interface language for the next run.)
@MainActor
final class LanguageUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testTheThreeLanguagesAreSeparateSettings() {
        let app = openLanguageAndRegion()
        XCTAssertTrue(app.buttons["language.appLanguageRow"].exists)
        XCTAssertTrue(app.buttons["language.voiceFollowingRow"].exists)
        XCTAssertTrue(app.buttons["language.scriptLanguageRow"].exists)

        app.buttons["language.voiceFollowingRow"].tap()
        tapOption(app, "language.voice.pt-BR")
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["language.scriptLanguageRow"].tap()
        tapOption(app, "language.script.pt-BR")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        XCTAssertTrue(app.buttons["language.voiceFollowingRow"].label.contains("Português (Brasil)"))
        XCTAssertTrue(app.buttons["language.scriptLanguageRow"].label.contains("Português (Brasil)"))
        // Neither one moved the interface: the tab bar is still in English.
        XCTAssertTrue(app.tabBars.buttons["Profile"].exists)
    }

    /// The creator's case: Cue in English, then Italian, while the script and Voice Following stay
    /// in Portuguese and the scripts stay exactly as written.
    func testAppLanguageOnlyChangesTheInterface() {
        let app = openLanguageAndRegion()
        app.buttons["language.voiceFollowingRow"].tap()
        tapOption(app, "language.voice.pt-BR")
        app.navigationBars.buttons.element(boundBy: 0).tap()

        app.buttons["language.appLanguageRow"].tap()
        tapOption(app, "language.app.it")
        // The interface switches right away and comes back to the same screen.
        XCTAssertTrue(app.tabBars.buttons["Profilo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["language.app.it"].isSelected)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.buttons["language.voiceFollowingRow"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["language.voiceFollowingRow"].label.contains("Português (Brasil)"))

        // Scripts are content: never translated.
        app.tabBars.buttons.element(boundBy: 0).tap()
        XCTAssertTrue(app.staticTexts["3 morning habits that changed my life"].waitForExistence(timeout: 5))

        // And back to English.
        app.tabBars.buttons["Profilo"].tap()
        app.buttons["language.appLanguageRow"].tap()
        tapOption(app, "language.app.en")
        XCTAssertTrue(app.tabBars.buttons["Profile"].waitForExistence(timeout: 5))
    }

    func testArabicLaysTheInterfaceOutRightToLeft() {
        let app = openLanguageAndRegion()
        app.buttons["language.appLanguageRow"].tap()
        tapOption(app, "language.app.ar")
        let row = app.buttons["language.app.ar"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        // The checkmark sits on the leading side, which is the right in Arabic: the row's label
        // starts past the middle of the screen.
        let title = row.staticTexts["العربية"]
        XCTAssertTrue(title.exists)
        XCTAssertGreaterThan(title.frame.midX, app.frame.midX)
        tapOption(app, "language.app.en")
        XCTAssertTrue(app.tabBars.buttons["Profile"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func openLanguageAndRegion() -> XCUIApplication {
        let app = CueApp.launch(seeded: true)
        let tab = app.tabBars.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let row = app.buttons["profile.languageButton"]
        for _ in 0..<8 where !(row.exists && row.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["language.appLanguageRow"].waitForExistence(timeout: 5))
        return app
    }

    /// Language lists are long; scrolls until the option can be tapped.
    private func tapOption(_ app: XCUIApplication, _ identifier: String) {
        let option = app.buttons[identifier]
        XCTAssertTrue(option.waitForExistence(timeout: 5))
        for _ in 0..<6 where !option.isHittable {
            app.swipeUp()
        }
        option.tap()
    }
}
