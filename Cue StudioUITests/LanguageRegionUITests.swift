//
//  LanguageRegionUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Settings › Language & Region: the app language (the iPhone's to change), the Voice Following language and the script language are
/// three settings, and changing one never changes another or translates a script.
@MainActor
final class LanguageRegionUITests: XCTestCase {
    private static let sampleTitle = "3 morning habits that changed my life"

    override func setUp() {
        continueAfterFailure = false
    }

    /// The app language row points at the iPhone's Settings; the other two are menus that start on "Same as script" and "Auto-detect".
    func testThePageHasThreeLanguagesAndTheAppOneIsTheIPhones() {
        let app = CueApp.launch(seeded: true)
        openLanguageRegion(app)
        XCTAssertTrue(row(app, "settings.appLanguage").label.contains("iPhone Language"))
        XCTAssertTrue(row(app, "settings.voiceFollowingLanguage").label.contains("Same as script"))
        XCTAssertTrue(row(app, "settings.scriptLanguage").label.contains("Auto-detect"))
    }

    func testVoiceFollowingLanguageChangesNothingElse() {
        let app = CueApp.launch(seeded: true)
        openLanguageRegion(app)
        pick("Português (Brasil)", from: "settings.voiceFollowingLanguage", in: app)

        XCTAssertTrue(row(app, "settings.voiceFollowingLanguage").label.contains("Português (Brasil)"))
        XCTAssertTrue(app.navigationBars["Language & Region"].exists)
        XCTAssertTrue(row(app, "settings.appLanguage").label.contains("iPhone Language"))
        XCTAssertTrue(row(app, "settings.scriptLanguage").label.contains("Auto-detect"))
    }

    func testScriptLanguageChangesNothingElse() {
        let app = CueApp.launch(seeded: true)
        openLanguageRegion(app)
        pick("日本語", from: "settings.scriptLanguage", in: app)

        XCTAssertTrue(row(app, "settings.scriptLanguage").label.contains("日本語"))
        XCTAssertTrue(app.navigationBars["Language & Region"].exists)
        XCTAssertTrue(row(app, "settings.voiceFollowingLanguage").label.contains("Same as script"))
    }

    /// The core case: Cue in Italian, a Portuguese script read aloud in Portuguese.
    func testItalianInterfaceWithPortugueseScriptAndVoice() {
        let app = CueApp.launch(seeded: true, appLanguage: "it")
        openLanguageRegion(app)
        XCTAssertTrue(app.navigationBars["Lingua e area geografica"].waitForExistence(timeout: 5))
        pick("Português (Brasil)", from: "settings.scriptLanguage", in: app)
        pick("Português (Brasil)", from: "settings.voiceFollowingLanguage", in: app)

        XCTAssertTrue(app.navigationBars["Lingua e area geografica"].waitForExistence(timeout: 5))
        XCTAssertTrue(row(app, "settings.appLanguage").label.contains("Italiano"))
        XCTAssertTrue(row(app, "settings.scriptLanguage").label.contains("Português (Brasil)"))
        XCTAssertTrue(row(app, "settings.voiceFollowingLanguage").label.contains("Português (Brasil)"))
    }

    /// Cue in Japanese with English scripts: the scripts stay in English.
    func testJapaneseInterfaceKeepsEnglishScripts() {
        let app = CueApp.launch(seeded: true, appLanguage: "ja")
        XCTAssertTrue(app.cueTabBar.buttons["台本"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.staticTexts[Self.sampleTitle].waitForExistence(timeout: 5))
    }

    /// Arabic mirrors the interface, whether picked in Cue or set on the iPhone: the new-script
    /// button moves to the other side.
    func testArabicLaysTheInterfaceOutRightToLeft() {
        let launches: [() -> XCUIApplication] = [
            { CueApp.launch(seeded: true, appLanguage: "ar") },
            { CueApp.launch(seeded: true, systemLanguage: "ar") },
        ]
        for launch in launches {
            let app = launch()
            let newScript = app.buttons["scripts.newButton"]
            XCTAssertTrue(newScript.waitForExistence(timeout: 15))
            XCTAssertLessThan(newScript.frame.midX, app.frame.midX)
            app.terminate()
        }
    }

    /// Captions listen in the script's language; when Voice Following listens in another one, the
    /// Captions tool says so instead of disagreeing silently.
    func testCaptionsSayWhenVoiceFollowingListensInAnotherLanguage() {
        let app = CueApp.launch(seeded: true, sampleVideo: true)
        openLanguageRegion(app)
        pick("Português (Brasil)", from: "settings.voiceFollowingLanguage", in: app)

        // The tab bar folds away while a list scrolls down: bring it back.
        app.swipeDown()
        app.cueTabBar.buttons["Takes"].tap()
        let takeRow = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")
        ).firstMatch
        XCTAssertTrue(takeRow.waitForExistence(timeout: 5))
        takeRow.tap()
        let edit = app.buttons["review.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        // The take has no captions yet: Captions opens Auto captions, where the language is chosen.
        XCTAssertTrue(app.buttons["edit.toolbar.edit"].waitForExistence(timeout: 10))
        EditorApp.tapTool(app, "captions")
        let note = app.staticTexts["edit.captionsLanguageNote"]
        XCTAssertTrue(note.waitForExistence(timeout: 5))
        XCTAssertTrue(note.label.contains("Portuguese (Brazil)"))
        EditorApp.done(app)
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func row(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openLanguageRegion(_ app: XCUIApplication) {
        // Settings is the fifth tab in any language.
        let settings = app.cueTabBar.buttons.element(boundBy: 4)
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        let page = row(app, "settings.languageRegion")
        app.scroll(to: page)
        page.tap()
        XCTAssertTrue(row(app, "settings.appLanguage").waitForExistence(timeout: 5))
    }

    /// Opens the menu of a language row and picks a language by its own name.
    private func pick(_ name: String, from rowID: String, in app: XCUIApplication) {
        row(app, rowID).tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", name)).firstMatch
        XCTAssertTrue(option.waitForExistence(timeout: 5), name)
        option.tap()
    }
}
