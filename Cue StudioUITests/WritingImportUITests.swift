//
//  WritingImportUITests.swift
//  Cue StudioUITests
//

import XCTest

/// "Import my writing": a creator brings texts from other apps, Cue reads them on the iPhone and says what it heard, and they keep it (or not).
/// The model is a stand-in (`-uiTestStubAI`); the numbers are the real analysis.
@MainActor
final class WritingImportUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Pictures are saved when `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` is set.
    private func capture(_ app: XCUIApplication, _ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Three short texts, each a dozen words or more, separated the way the sheet asks.
    private let writing = [
        "Okay, real talk. Do you really need a gym membership to get stronger this year? I do not think so. Save this for later!",
        "Okay, real talk. Why are your shoulders always sore after every single workout? You skip the warm up. Save this for later!",
        "Okay, real talk. Is your protein actually enough for the training you do every week? Most people guess. Save this for later!",
    ].joined(separator: "\n---\n")

    private func openImport(_ app: XCUIApplication) {
        // Profile is the one before the last tab (Scripts, Takes, Record, Profile, Settings), whatever language its name is in.
        XCTAssertTrue(app.cueTabBar.waitForExistence(timeout: 15))
        let tabs = app.cueTabBar.buttons.allElementsBoundByIndex
        let tab = tabs.count >= 2 ? tabs[tabs.count - 2] : app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        let setUp = app.buttons["profile.setUpVoiceButton"]
        XCTAssertTrue(setUp.waitForExistence(timeout: 5))
        setUp.tap()
        app.buttons["voiceSetup.skipRole"].tap()
        app.buttons["voiceSetup.niche.food"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.audience.parents"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.tone.casual"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        XCTAssertTrue(element(app, "profile.voiceSentence").waitForExistence(timeout: 5))
        let edit = app.buttons["profile.editVoice"]
        app.scroll(to: edit)
        edit.tap()
        let row = element(app, "voicePage.row.examples")
        app.scroll(to: row)
        row.tap()
        let importButton = app.buttons["voice.import"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        capture(app, "examples_editor_\(app.launchArguments.contains("ar") ? "ar" : "en")")
        importButton.tap()
        XCTAssertTrue(element(app, "import.sheet").waitForExistence(timeout: 5))
    }

    private func bringTexts(_ app: XCUIApplication) {
        let field = app.textViews["import.field"].exists ? app.textViews["import.field"] : app.textFields["import.field"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        field.typeText(writing)
        app.buttons["import.add"].tap()
        XCTAssertTrue(element(app, "import.count").waitForExistence(timeout: 5))
    }

    func testBringingTextsReadingAndKeepingWhatCueHeard() {
        let app = CueApp.launch(seeded: true, ai: .stub, animations: false)
        openImport(app)
        XCTAssertFalse(app.buttons["import.read"].isEnabled, "nothing to read yet")
        bringTexts(app)
        XCTAssertFalse(app.buttons["import.read"].isEnabled, "the creator has not said these are their own words")
        XCTAssertTrue(element(app, "import.count").label.contains("3"))
        app.switches["import.own"].tap()
        XCTAssertTrue(app.buttons["import.read"].isEnabled)
        capture(app, "import_1_collect")
        app.buttons["import.read"].tap()

        XCTAssertTrue(element(app, "import.review").waitForExistence(timeout: 20))
        XCTAssertTrue(element(app, "import.summary").label.contains("3"))
        capture(app, "import_2_review")
        XCTAssertTrue(element(app, "import.finding.tones").exists, "the stand-in model said how they sound")
        XCTAssertTrue(element(app, "import.finding.phrases").exists, "'Okay, real talk' comes back in every text")
        app.buttons["import.accept"].tap()

        XCTAssertTrue(element(app, "voice.import.count").waitForExistence(timeout: 5), "the editor shows what was imported")
        XCTAssertFalse(app.buttons["voice.import"].exists)
    }

    /// The day after: the creator opens "What Cue sends" and finds what they imported in it, and the page row says how many excerpts there are.
    func testWhatCueSendsShowsWhatWasImportedAndTheRowCountsIt() {
        let app = CueApp.launch(seeded: true, ai: .stub, animations: false)
        openImport(app)
        bringTexts(app)
        app.switches["import.own"].tap()
        app.buttons["import.read"].tap()
        XCTAssertTrue(element(app, "import.review").waitForExistence(timeout: 20))
        app.buttons["import.accept"].tap()
        XCTAssertTrue(element(app, "voice.import.count").waitForExistence(timeout: 5))
        app.buttons["voice.editor.done"].tap()
        let row = element(app, "voicePage.row.examples")
        app.scroll(to: row)
        XCTAssertTrue(row.label.contains("Imported"), "the row says how many were imported: \(row.label)")
        let sends = element(app, "voicePage.sends")
        app.scroll(to: sends)
        sends.tap()
        let brief = element(app, "voice.sends.brief")
        XCTAssertTrue(brief.waitForExistence(timeout: 5))
        XCTAssertTrue(brief.label.contains("Here is how they write"), "the brief holds the creator's own sentences")
        XCTAssertTrue(brief.label.contains("Okay, real talk"))
        capture(app, "import_what_cue_sends")
    }

    func testForgettingWhatWasImportedBringsTheButtonBack() {
        let app = CueApp.launch(seeded: true, ai: .stub, animations: false)
        openImport(app)
        bringTexts(app)
        app.switches["import.own"].tap()
        app.buttons["import.read"].tap()
        XCTAssertTrue(element(app, "import.review").waitForExistence(timeout: 20))
        app.buttons["import.accept"].tap()
        let forget = app.buttons["voice.import.forget"]
        XCTAssertTrue(forget.waitForExistence(timeout: 5))
        forget.tap()
        XCTAssertTrue(app.buttons["voice.import"].waitForExistence(timeout: 5))
    }

    func testAFewWordsAreSaidNotToBeEnoughAndTheCreatorCanGoBack() {
        let app = CueApp.launch(seeded: true, ai: .stub, animations: false)
        openImport(app)
        let field = app.textViews["import.field"].exists ? app.textViews["import.field"] : app.textFields["import.field"]
        field.tap()
        field.typeText("hello there")
        app.buttons["import.add"].tap()
        XCTAssertTrue(element(app, "import.pasteEmpty").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["import.read"].isEnabled)
    }

    func testCancellingWhileCueReadsKeepsTheTexts() {
        let app = CueApp.launch(seeded: true, ai: .stub, animations: false)
        openImport(app)
        bringTexts(app)
        app.switches["import.own"].tap()
        app.buttons["import.read"].tap()
        // The stand-in answers at once: either the reading screen is still up and Cancel works, or the review is already there and Back does.
        if app.buttons["import.cancel"].waitForExistence(timeout: 1) {
            app.buttons["import.cancel"].tap()
        } else {
            XCTAssertTrue(element(app, "import.review").waitForExistence(timeout: 20))
            app.buttons["import.back"].tap()
        }
        XCTAssertTrue(element(app, "import.count").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "import.count").label.contains("3"))
    }

    func testWithoutAppleIntelligenceTheImportStillWorksWithTheMeasures() {
        let app = CueApp.launch(seeded: true, ai: .none, animations: false)
        openImport(app)
        bringTexts(app)
        app.switches["import.own"].tap()
        app.buttons["import.read"].tap()
        XCTAssertTrue(element(app, "import.review").waitForExistence(timeout: 20))
        XCTAssertTrue(element(app, "import.finding.phrases").exists)
        XCTAssertFalse(element(app, "import.finding.tones").exists, "no model, no tone")
    }

    /// The sheet is in the creator's language, and in a language that reads from right to left it still holds together.
    func testTheSheetSpeaksTheAppLanguageInPortugueseAndArabic() {
        for (language, title) in [("pt-BR", "Importar meus textos"), ("ar", "استيراد كتاباتي")] {
            let app = CueApp.launch(seeded: true, ai: .stub, appLanguage: language, animations: false)
            openImport(app)
            XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5), "\(language): the title is translated")
            XCTAssertFalse(app.staticTexts["Import my writing"].exists, "\(language): no English left on the sheet")
            capture(app, "import_collect_\(language)")
            bringTexts(app)
            app.switches["import.own"].tap()
            app.buttons["import.read"].tap()
            XCTAssertTrue(element(app, "import.review").waitForExistence(timeout: 20))
            capture(app, "import_review_\(language)")
            app.terminate()
        }
    }
}
