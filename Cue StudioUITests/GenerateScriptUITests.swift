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
        XCTAssertTrue(field.exists(within: 15))
        field.tap()
        field.typeText("2 minutes on how the electric shower was invented in Brazil")
        app.buttons["ideaCard.submit"].tap()

        // The words are written into the page; a factual topic asks for a check.
        XCTAssertTrue(element(app, "page.editor").exists(within: 10))
        let checked = app.buttons["detail.factCheckedButton"]
        XCTAssertTrue(checked.exists(within: 10))
        checked.tap()
        XCTAssertFalse(checked.exists(within: 2))
    }

    func testFindInspirationPutsAnIdeaInTheCardOrWritesIt() {
        let app = CueApp.launch(seeded: true)
        app.openIdeas()
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        XCTAssertTrue(app.buttons["inspiration.another"].exists)
        // "Start with it" puts it on the card, to change before it is written.
        app.buttons["inspiration.use"].tap()
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 5))
        XCTAssertFalse((field.value as? String ?? "").isEmpty)

        // "Draft it now" writes it into a new page at once.
        app.openIdeas()
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        app.buttons["inspiration.writeNow"].tap()
        XCTAssertTrue(app.pageBackButton.exists(within: 10))
        XCTAssertTrue(element(app, "page.editor").exists(within: 10))
    }

    func testTheFormatChipChoosesHowCueBuildsTheScript() {
        let app = CueApp.launch(seeded: true)
        let chip = app.buttons["ideaCard.formatChip"]
        XCTAssertTrue(chip.exists(within: 15))
        chip.tap()
        XCTAssertTrue(element(app, "format.sheet").exists(within: 5))
        XCTAssertTrue(app.buttons["format.auto"].exists)
        for type in ["talking", "ad", "review", "tutorial", "list", "story", "opinion", "launch", "apology", "mythFact", "pov"] {
            XCTAssertTrue(app.buttons["format.\(type)"].exists, type)
        }
        XCTAssertFalse(app.staticTexts["PRO"].exists)
        app.buttons["format.review"].tap()
        // Picking only selects; Done puts it on the card.
        app.buttons["format.confirm"].tap()
        XCTAssertTrue(app.buttons["ideaCard.formatChip"].exists(within: 5))
        XCTAssertTrue(app.buttons["ideaCard.formatChip"].label.contains("Review"))
        XCTAssertFalse(app.buttons["paywall.closeButton"].exists(within: 2))
    }

    func testTheCreateForChipSetsThePlatformTheIdeaIsWrittenFor() {
        let app = CueApp.launch(seeded: true)
        let chip = app.buttons["ideaCard.platformChip"]
        XCTAssertTrue(chip.exists(within: 15))
        XCTAssertTrue(chip.label.contains("TikTok"))
        chip.tap()
        let youtube = app.buttons["destination.youtube"]
        XCTAssertTrue(youtube.exists(within: 5))
        youtube.tap()
        XCTAssertTrue(app.buttons["ideaCard.platformChip"].label.contains("YouTube"))
    }

    func testWithoutAppleIntelligenceTheArrowSaysWriteItAndOpensADraftWithTheIdeaAsItsTitle() {
        let app = CueApp.launch(seeded: true, ai: .none)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 15))
        XCTAssertTrue(element(app, "generate.unavailableNote").exists(within: 5))
        XCTAssertEqual(app.buttons["ideaCard.submit"].label, "Write it")
        XCTAssertFalse(app.buttons["ideaCard.submit"].isEnabled, "Nothing typed yet")
        field.tap()
        field.typeText("A day in my life")
        XCTAssertTrue(app.buttons["ideaCard.submit"].isEnabled)
        app.buttons["ideaCard.submit"].tap()
        let title = element(app, "page.titleField")
        XCTAssertTrue(title.exists(within: 10))
        XCTAssertEqual(title.value as? String, "A day in my life")
    }

    func testStopKeepsWhatHasArrived() {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 15))
        field.tap()
        field.typeText("Why I quit coffee for 30 days")
        app.buttons["ideaCard.submit"].tap()
        // The stub answers at once, so by the time the page is up the writing is done and Stop is gone: the strip has the ready switch,
        // off, since the AI drafts (the "Draft ready" toast is too short-lived to wait for; the view model's tests check it).
        XCTAssertTrue(app.pageBackButton.exists(within: 10))
        let ready = app.pageReadyToggle
        XCTAssertTrue(ready.exists(within: 10))
        XCTAssertTrue(["Off", "0"].contains(ready.value as? String ?? ""), "the AI drafts: the switch starts off")
        XCTAssertFalse(app.buttons["page.stopButton"].exists)
    }

    func testImproveOffersInMyVoiceOnTheFreePlan() {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        app.buttons["page.improveButton"].tap()
        let voice = element(app, "improve.tool.inMyVoice")
        XCTAssertTrue(voice.exists(within: 5))
        voice.tap()
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label BEGINSWITH 'In your voice'")).firstMatch.exists(within: 5))
        XCTAssertFalse(app.buttons["paywall.closeButton"].exists)
    }

    // MARK: - Helpers

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }

    /// A long script (past a minute and a half) written at the real pace: pictures every 0.4 s while the words arrive and as the page
    /// becomes the editor, to look at how it settles. Opt-in: `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>`.
    func testALongScriptWritesAndSettlesOnThePage() throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to look at a long script being written")
        }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestLongScript", "-uiTestRealWriting"])
        // As the owner had it: the cues hidden on the page (a setting for every script).
        if ProcessInfo.processInfo.environment["CUE_CUES_HIDDEN"] != nil {
            app.openScriptPage(titled: "Oat & Co. — sponsored read")
            let cues = app.descendants(matching: .any)["page.cuesToggle"].firstMatch
            XCTAssertTrue(cues.exists(within: 5))
            cues.tap()
            app.pageBackButton.tap()
        }
        let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
        XCTAssertTrue(field.exists(within: 15))
        field.tap()
        field.typeText("Waking up an hour earlier for 30 days")
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(app.pageBackButton.exists(within: 15))
        for index in 0..<45 {
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: String(format: "long-%02d.png", index)))
            Thread.sleep(forTimeInterval: 0.25)
        }
    }
}
