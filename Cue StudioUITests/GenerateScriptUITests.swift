//
//  GenerateScriptUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Writing from an idea: the arrow on the card, "Need an idea?" and "Format", the fact check, and a
/// device without Apple Intelligence.
@MainActor
final class GenerateScriptUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testFactualIdeaIsFlaggedUntilChecked() {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("2 minutes on how the electric shower was invented in Brazil")
        app.buttons["ideaCard.submit"].tap()

        // The words are written into the page; a factual topic asks for a check.
        XCTAssertTrue(element(app, "page.editor").waitForExistence(timeout: 10))
        let checked = app.buttons["detail.factCheckedButton"]
        XCTAssertTrue(checked.waitForExistence(timeout: 10))
        checked.tap()
        XCTAssertFalse(checked.waitForExistence(timeout: 2))
    }

    func testIdeasSheetOffersIdeasWritesOneAndEditsAnother() {
        let app = CueApp.launch(seeded: true)
        app.openIdeas()
        let firstIdea = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ideas.write.'")).firstMatch
        XCTAssertTrue(firstIdea.waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ideas.moreButton"].exists)
        // A tap on the idea itself puts it on the card, to change before it is written.
        let row = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'ideas.row.'")).firstMatch
        row.buttons.firstMatch.tap()
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue((field.value as? String)?.contains("video:") == true)

        // ↑ writes it into a new page at once.
        app.openIdeas()
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ideas.write.'")).firstMatch.tap()
        XCTAssertTrue(app.pageBackButton.waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "page.editor").waitForExistence(timeout: 10))
    }

    func testTheFormatChipChoosesHowCueBuildsTheScript() {
        let app = CueApp.launch(seeded: true)
        let chip = app.buttons["ideaCard.formatChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        XCTAssertTrue(element(app, "format.sheet").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["format.auto"].exists)
        for type in ["talking", "ad", "review", "tutorial", "list", "story", "opinion", "launch", "apology", "mythFact", "pov"] {
            XCTAssertTrue(app.buttons["format.\(type)"].exists, type)
        }
        XCTAssertFalse(app.staticTexts["PRO"].exists)
        app.buttons["format.review"].tap()
        // Picking only selects; Done puts it on the card.
        app.buttons["format.confirm"].tap()
        XCTAssertTrue(app.buttons["ideaCard.formatChip"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["ideaCard.formatChip"].label.contains("Review"))
        XCTAssertFalse(app.buttons["paywall.closeButton"].waitForExistence(timeout: 2))
    }

    func testTheCreateForChipSetsThePlatformTheIdeaIsWrittenFor() {
        let app = CueApp.launch(seeded: true)
        let chip = app.buttons["ideaCard.platformChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        XCTAssertTrue(chip.label.contains("TikTok"))
        chip.tap()
        let youtube = app.buttons["destination.youtube"]
        XCTAssertTrue(youtube.waitForExistence(timeout: 5))
        youtube.tap()
        XCTAssertTrue(app.buttons["ideaCard.platformChip"].label.contains("YouTube"))
    }

    func testWithoutAppleIntelligenceTheArrowSaysWriteItAndOpensADraftWithTheIdeaAsItsTitle() {
        let app = CueApp.launch(seeded: true, ai: .none)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "generate.unavailableNote").waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["ideaCard.submit"].label, "Write it")
        XCTAssertFalse(app.buttons["ideaCard.submit"].isEnabled, "Nothing typed yet")
        field.tap()
        field.typeText("A day in my life")
        XCTAssertTrue(app.buttons["ideaCard.submit"].isEnabled)
        app.buttons["ideaCard.submit"].tap()
        let title = element(app, "page.titleField")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        XCTAssertEqual(title.value as? String, "A day in my life")
    }

    func testStopKeepsWhatHasArrived() {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Why I quit coffee for 30 days")
        app.buttons["ideaCard.submit"].tap()
        // The stub answers at once, so by the time the page is up the writing is done and Stop is gone: the strip has Done in its
        // place (the "Draft ready" toast is too short-lived to wait for; the view model's tests check it).
        XCTAssertTrue(app.pageBackButton.waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["page.doneButton"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["page.stopButton"].exists)
    }

    func testImproveOffersInMyVoiceOnTheFreePlan() {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        app.buttons["page.improveButton"].tap()
        let voice = element(app, "improve.tool.inMyVoice")
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        voice.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'Rewrote in your voice'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["paywall.closeButton"].exists)
    }

    // MARK: - Helpers

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
