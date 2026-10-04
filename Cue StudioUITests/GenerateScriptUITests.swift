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
        XCTAssertTrue(element(app, "page.draftEditor").waitForExistence(timeout: 10))
        let checked = app.buttons["detail.factCheckedButton"]
        app.buttons["page.mode.shaped"].tap()
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
        XCTAssertTrue(app.buttons["page.backButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "page.draftEditor").waitForExistence(timeout: 10))
    }

    func testTheFormatChipChoosesHowCueBuildsTheScript() {
        let app = CueApp.launch(seeded: true)
        let chip = app.buttons["ideaCard.formatChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        XCTAssertTrue(element(app, "format.sheet").waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["format.auto"].exists)
        for type in ["ad", "review", "tutorial", "list", "story", "opinion", "launch", "apology"] {
            XCTAssertTrue(app.buttons["format.\(type)"].exists, type)
        }
        XCTAssertFalse(app.staticTexts["PRO"].exists)
        app.buttons["format.review"].tap()
        // The card says which one is chosen.
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

    func testWithoutAppleIntelligenceTheArrowStaysOffForATypedIdeaButIdeasAreStillThere() {
        let app = CueApp.launch(seeded: true, ai: .none)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "generate.unavailableNote").waitForExistence(timeout: 5))
        field.tap()
        field.typeText("A day in my life")
        XCTAssertFalse(app.buttons["ideaCard.submit"].isEnabled)
        // The ideas are local: they open, and ↑ is off since nothing can write them.
        app.buttons["ideaCard.ideasChip"].tap()
        XCTAssertTrue(element(app, "ideas.sheet").waitForExistence(timeout: 5))
        let write = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'ideas.write.'")).firstMatch
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        XCTAssertFalse(write.isEnabled)
    }

    func testStopKeepsWhatHasArrived() {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("Why I quit coffee for 30 days")
        app.buttons["ideaCard.submit"].tap()
        // The stub answers at once, so by the time the page is up the writing is done and Stop is gone.
        XCTAssertTrue(app.buttons["page.backButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Draft ready'")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["page.stopButton"].exists)
    }

    func testTheFullEditorOffersInMyVoiceOnTheFreePlan() {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        for _ in 0..<4 where !row.isHittable { app.swipeUp() }
        row.tap()
        app.buttons["page.menuButton"].tap()
        app.buttons["Versions & options"].tap()
        // AI is one of the bar's panels; its tools are in the grid.
        app.buttons["editor.tool.ai"].tap()
        let voice = element(app, "editor.tool.inMyVoice")
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
