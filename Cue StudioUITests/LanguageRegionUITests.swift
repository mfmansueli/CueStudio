//
//  LanguageRegionUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Settings › Language & Region: the app language, the Voice Following language and the script
/// language are three settings, and changing one never changes another or translates a script.
@MainActor
final class LanguageRegionUITests: XCTestCase {
    private static let sampleTitle = "3 morning habits that changed my life"

    override func setUp() {
        continueAfterFailure = false
    }

    /// The interface switches at once, the creator stays on Language & Region, and nothing else
    /// changes: the other two languages, and the scripts, which are never translated.
    func testAppLanguageSwitchesTheInterfaceAndNothingElse() {
        let app = CueApp.launch(seeded: true)
        openLanguageRegion(app)
        app.buttons["languageRegion.appLanguageButton"].tap()
        pick("pt-BR", in: app)

        XCTAssertTrue(app.navigationBars["Idioma e região"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.cueTabBar.buttons["Perfil"].exists)
        XCTAssertTrue(app.cueTabBar.buttons["Ajustes"].isSelected)
        XCTAssertTrue(app.buttons["languageRegion.appLanguageButton"].label.contains("Português (Brasil)"))
        XCTAssertTrue(app.buttons["languageRegion.voiceFollowingLanguageButton"].label.contains("Igual ao roteiro"))
        XCTAssertTrue(app.buttons["languageRegion.scriptLanguageButton"].label.contains("Detectar automaticamente"))

        // Language & Region is a sheet: close it to reach the tabs.
        app.buttons["settings.sheetDone"].tap()
        app.cueTabBar.buttons["Roteiros"].tap()
        let sample = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", Self.sampleTitle)).firstMatch
        XCTAssertTrue(sample.waitForExistence(timeout: 5))
    }

    func testVoiceFollowingLanguageChangesNothingElse() {
        let app = CueApp.launch(seeded: true)
        openLanguageRegion(app)
        app.buttons["languageRegion.voiceFollowingLanguageButton"].tap()
        pick("pt-BR", in: app)

        let row = app.buttons["languageRegion.voiceFollowingLanguageButton"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("Português (Brasil)"))
        XCTAssertTrue(app.navigationBars["Language & Region"].exists)
        XCTAssertTrue(app.buttons["languageRegion.appLanguageButton"].label.contains("iPhone Language"))
        XCTAssertTrue(app.buttons["languageRegion.scriptLanguageButton"].label.contains("Auto-detect"))
    }

    func testScriptLanguageChangesNothingElse() {
        let app = CueApp.launch(seeded: true)
        openLanguageRegion(app)
        app.buttons["languageRegion.scriptLanguageButton"].tap()
        pick("ja-JP", in: app)

        let row = app.buttons["languageRegion.scriptLanguageButton"]
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        XCTAssertTrue(row.label.contains("日本語"))
        XCTAssertTrue(app.navigationBars["Language & Region"].exists)
        XCTAssertTrue(app.buttons["languageRegion.voiceFollowingLanguageButton"].label.contains("Same as Script"))
    }

    /// The core case: Cue in Italian, a Portuguese script read aloud in Portuguese.
    func testItalianInterfaceWithPortugueseScriptAndVoice() {
        let app = CueApp.launch(seeded: true, appLanguage: "it")
        openLanguageRegion(app)
        XCTAssertTrue(app.navigationBars["Lingua e area geografica"].waitForExistence(timeout: 5))
        app.buttons["languageRegion.scriptLanguageButton"].tap()
        pick("pt-BR", in: app)
        app.buttons["languageRegion.voiceFollowingLanguageButton"].tap()
        pick("pt-BR", in: app)

        XCTAssertTrue(app.navigationBars["Lingua e area geografica"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["languageRegion.appLanguageButton"].label.contains("Italiano"))
        XCTAssertTrue(app.buttons["languageRegion.scriptLanguageButton"].label.contains("Português (Brasil)"))
        XCTAssertTrue(app.buttons["languageRegion.voiceFollowingLanguageButton"].label.contains("Português (Brasil)"))
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
        app.buttons["languageRegion.voiceFollowingLanguageButton"].tap()
        pick("pt-BR", in: app)
        XCTAssertTrue(app.buttons["languageRegion.voiceFollowingLanguageButton"].waitForExistence(timeout: 5))

        app.buttons["settings.sheetDone"].tap()
        app.cueTabBar.buttons["Takes"].tap()
        let row = app.buttons.matching(
            NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")
        ).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
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

    private func openLanguageRegion(_ app: XCUIApplication) {
        // Settings is the fifth tab in any language.
        let settings = app.cueTabBar.buttons.element(boundBy: 4)
        XCTAssertTrue(settings.waitForExistence(timeout: 15))
        settings.tap()
        let row = app.buttons["settings.languageRegionButton"]
        for _ in 0..<8 where !(row.exists && row.isHittable) {
            app.swipeUp()
        }
        row.tap()
        XCTAssertTrue(app.buttons["languageRegion.appLanguageButton"].waitForExistence(timeout: 5))
    }

    private func pick(_ option: String, in app: XCUIApplication) {
        let button = app.buttons["languagePicker.option.\(option)"]
        for _ in 0..<6 where !(button.exists && button.isHittable) {
            app.swipeUp()
        }
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }
}
