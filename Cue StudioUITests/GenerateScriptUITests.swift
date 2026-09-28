//
//  GenerateScriptUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Generate with AI: Prompt, Themes and Formats, the fact check, and a device without Apple
/// Intelligence.
@MainActor
final class GenerateScriptUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFactualPromptIsFlaggedUntilChecked() {
        let app = CueApp.launch(seeded: true)
        openNewScript(app)
        app.buttons["newScript.prompt"].tap()

        let field = element(app, "generate.promptField")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'AI can get facts wrong'")).firstMatch.exists)
        app.buttons["2 minutes on how the electric shower was invented in Brazil"].tap()
        app.buttons["generate.generateButton"].tap()

        let done = app.buttons["editor.doneButton"]
        XCTAssertTrue(done.waitForExistence(timeout: 10))
        done.tap()
        let checked = app.buttons["detail.factCheckedButton"]
        XCTAssertTrue(checked.waitForExistence(timeout: 5))
        checked.tap()
        XCTAssertFalse(checked.waitForExistence(timeout: 2))
    }

    func testThemeIdeaFillsThePrompt() {
        let app = CueApp.launch(seeded: true)
        openNewScript(app)
        app.buttons["newScript.themes"].tap()

        let firstIdea = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'generate.theme.'")).firstMatch
        XCTAssertTrue(firstIdea.waitForExistence(timeout: 5))
        firstIdea.tap()
        let field = element(app, "generate.promptField")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue((field.value as? String)?.contains("video:") == true)
    }

    func testSponsoredAdIsPro() {
        let app = CueApp.launch(seeded: true)
        openNewScript(app)
        app.buttons["newScript.formats"].tap()
        let ad = app.buttons["generate.type.ad"]
        XCTAssertTrue(ad.waitForExistence(timeout: 5))
        ad.tap()
        XCTAssertTrue(app.staticTexts["Brand deals, done right"].waitForExistence(timeout: 5))
    }

    func testWithoutAppleIntelligenceThePromptIsOffButFormatsWork() {
        let app = CueApp.launch(seeded: true, ai: .none)
        openNewScript(app)
        app.buttons["newScript.prompt"].tap()
        XCTAssertTrue(element(app, "generate.unavailableNote").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["generate.generateButton"].isEnabled)

        app.segmentedControls.buttons["Formats"].tap()
        app.buttons["generate.type.review"].tap()
        let generate = app.buttons["generate.generateButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 10))
    }

    func testEditorOffersInMyVoice() {
        let app = CueApp.launch(seeded: true, pro: true)
        openEditorVoiceTool(app).tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Rewrote in your voice'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testInMyVoiceIsProOnTheFreePlan() {
        let app = CueApp.launch(seeded: true)
        openEditorVoiceTool(app).tap()
        XCTAssertTrue(app.staticTexts["AI that sounds like you"].waitForExistence(timeout: 5))
    }

    // MARK: - Helpers

    private func openEditorVoiceTool(_ app: XCUIApplication) -> XCUIElement {
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        app.buttons["detail.editButton"].tap()
        let voice = element(app, "editor.tool.inMyVoice")
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        return voice
    }

    private func openNewScript(_ app: XCUIApplication) {
        let plus = app.buttons["scripts.newButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()
        XCTAssertTrue(app.buttons["newScript.prompt"].waitForExistence(timeout: 5))
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
