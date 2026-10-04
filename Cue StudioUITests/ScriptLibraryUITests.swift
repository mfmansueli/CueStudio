//
//  ScriptLibraryUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Browsing, filtering and opening scripts: the Recent list with each script at its stage, and the
/// script page (Draft | Shaped).
@MainActor
final class ScriptLibraryUITests: XCTestCase {
    private static let habits = "3 morning habits that changed my life"
    private static let lamp = "Unboxing the Lumen desk lamp"

    override func setUp() {
        continueAfterFailure = false
    }

    func testTheListShowsEachScriptAtItsState() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(element(app, "scripts.summary").waitForExistence(timeout: 15))
        // READY TO RECORD first, then DRAFTS, then RECORDED; each has its way forward.
        XCTAssertTrue(element(app, "scripts.group.ready").exists)
        XCTAssertTrue(app.buttons["row.recordButton"].firstMatch.exists)
        for _ in 0..<4 where !element(app, "scripts.group.recorded").exists { app.swipeUp() }
        XCTAssertTrue(element(app, "scripts.group.draft").exists)
        XCTAssertTrue(element(app, "scripts.group.recorded").exists)
        XCTAssertTrue(element(app, "row.takes").exists)
        // A recorded script's line carries its takes and the stage of its video.
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '3 takes'")).firstMatch.exists)
    }

    func testFilteringByDestination() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.buttons["scripts.filter.reels"].waitForExistence(timeout: 15))
        app.buttons["scripts.filter.reels"].tap()
        XCTAssertTrue(app.scriptRow(Self.lamp).exists)
        XCTAssertFalse(app.staticTexts["Oat & Co. — sponsored read"].exists)
    }

    func testPromptBoxStaysOnTop() {
        let app = CueApp.launch(seeded: true)
        let prompt = element(app, "scripts.promptCard")
        XCTAssertTrue(prompt.waitForExistence(timeout: 15))

        // The magnifier brings the search under the card; no filter, search or selection hides the card.
        app.buttons["scripts.searchButton"].tap()
        let search = element(app, "scripts.searchField")
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        XCTAssertLessThan(prompt.frame.minY, search.frame.minY)
        app.buttons["scripts.selectButton"].tap()
        XCTAssertTrue(prompt.exists)
        app.buttons["scripts.selectButton"].tap()
        search.tap()
        search.typeText("nothing matches this")
        XCTAssertTrue(element(app, "scripts.empty").waitForExistence(timeout: 5))
        XCTAssertTrue(prompt.exists)
    }

    func testTheCardsArrowWritesTheIdeaIntoANewPage() {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("A day in my life")
        app.buttons["ideaCard.submit"].tap()
        // The page opens and the words arrive on it, in the Draft; the card is empty again.
        XCTAssertTrue(app.buttons["page.backButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "page.editor").waitForExistence(timeout: 10))
        XCTAssertTrue((element(app, "page.editor").value as? String)?.contains("Save this for later") == true)
        XCTAssertEqual((element(app, "page.titleField").value as? String), "A day in my life")
        app.buttons["page.backButton"].tap()
        XCTAssertTrue(element(app, "ideaCard.field").waitForExistence(timeout: 5))
        XCTAssertNotEqual(element(app, "ideaCard.field").value as? String, "A day in my life")
    }

    func testAnimatedPromptKeepsItsFrameAndAction() {
        let app = CueApp.launch(seeded: true)
        let prompt = element(app, "scripts.promptCard")
        XCTAssertTrue(prompt.waitForExistence(timeout: 15))
        let frame = prompt.frame
        let label = prompt.label
        let before = XCTAttachment(screenshot: app.screenshot())
        before.name = "Prompt light — initial frame"
        before.lifetime = .keepAlways
        add(before)

        let moved = XCTNSPredicateExpectation(predicate: NSPredicate { _, _ in
            prompt.frame != frame || prompt.label != label
        }, object: nil)
        moved.isInverted = true
        wait(for: [moved], timeout: 6)
        XCTAssertTrue(prompt.isHittable)
        let after = XCTAttachment(screenshot: app.screenshot())
        after.name = "Prompt light — after six seconds"
        after.lifetime = .keepAlways
        add(after)

        // Its field takes the keyboard in place; no page opens until the arrow is tapped.
        element(app, "ideaCard.field").tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["page.backButton"].exists)
    }

    func testSearch() {
        let app = CueApp.launch(seeded: true)
        let magnifier = app.buttons["scripts.searchButton"]
        XCTAssertTrue(magnifier.waitForExistence(timeout: 15))
        magnifier.tap()
        let search = element(app, "scripts.searchField")
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Q&A")
        XCTAssertTrue(app.staticTexts["Weekly Q&A — episode 12"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[Self.lamp].exists)
    }

    // MARK: - Navigation

    func testExistingScriptReturnsToScriptsWithOneBackTap() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        app.buttons["page.backButton"].tap()
        XCTAssertTrue(element(app, "scripts.promptCard").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["detail.recordButton"].exists)
    }

    func testSavingAnExistingScriptAndReopeningItStillNeedsOnlyOneBackTap() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText(" Updated for navigation testing.")
        app.buttons["page.backButton"].tap()
        XCTAssertTrue(element(app, "scripts.promptCard").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["detail.recordButton"].exists)

        // Saving promotes this row to the one edited last, but must not create another page.
        openScript(app, Self.lamp)
        app.buttons["page.backButton"].tap()
        XCTAssertTrue(element(app, "scripts.promptCard").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["detail.recordButton"].exists)
    }

    func testDifferentScriptsAndRepeatedOpensDoNotAccumulatePages() {
        let app = CueApp.launch(seeded: true)
        for title in [Self.habits, Self.lamp, Self.habits] {
            openScript(app, title)
            XCTAssertTrue(app.staticTexts[title].exists || (element(app, "page.titleField").value as? String) == title)
            app.buttons["page.backButton"].tap()
            XCTAssertTrue(element(app, "scripts.promptCard").waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["detail.recordButton"].exists)
        }
    }

    func testNewScriptOpensInTheDraftWithTheTitleReady() {
        let app = CueApp.launch(seeded: true)
        let plus = app.buttons["scripts.newButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()
        let write = app.buttons["newScript.write"]
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        write.tap()
        let title = element(app, "page.titleField")
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "page.editor").exists)
        title.typeText("One-tap navigation script")
        app.buttons["page.backButton"].tap()
        XCTAssertTrue(element(app, "scripts.promptCard").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["detail.recordButton"].exists)
        // A blank draft opens straight into writing (Continue ›), with the keyboard up.
        app.staticTexts["One-tap navigation script"].tap()
        XCTAssertTrue(app.buttons["page.backButton"].waitForExistence(timeout: 5))
        app.buttons["page.backButton"].tap()
        XCTAssertTrue(element(app, "scripts.promptCard").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["page.backButton"].exists)
    }

    func testStudioAndRecordReturnToTheSamePageWithoutAddingAnotherRoute() {
        let app = CueApp.launch(seeded: true)
        for action in ["Studio mode", "Rec"] {
            openScript(app, Self.habits)
            if action == "Studio mode" {
                app.buttons["page.menuButton"].tap()
                app.buttons["Studio mode"].firstMatch.tap()
            } else {
                app.buttons["detail.recordButton"].tap()
            }
            let close = app.buttons["prompter.closeButton"]
            XCTAssertTrue(close.waitForExistence(timeout: 10))
            close.tap()
            XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 5))
            app.buttons["page.backButton"].tap()
            XCTAssertTrue(element(app, "scripts.promptCard").waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["detail.recordButton"].exists)
        }
    }

    // MARK: - The page

    func testThePageHasTheStripTheLengthAndExactlyOneRecordButton() {
        let app = CueApp.launch(seeded: true)
        openScript(app, "Oat & Co. — sponsored read")
        XCTAssertTrue(element(app, "page.strip").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "page.lengthBar").exists)
        XCTAssertTrue(element(app, "page.meter").label.localizedCaseInsensitiveContains("words"))
        XCTAssertTrue(element(app, "page.editor").exists)
        // The Draft | Shaped switch is gone; Record is the page's only one.
        XCTAssertFalse(app.buttons["page.mode.draft"].exists || app.buttons["page.mode.shaped"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "detail.recordButton").count, 1)
    }

    func testACueFromTheBarGoesIntoTheText() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        XCTAssertTrue(element(app, "page.cuesBar").waitForExistence(timeout: 5))
        app.buttons["page.cue.pause"].tap()
        XCTAssertTrue((text.value as? String)?.contains("[pause]") == true)
    }

    func testTheHookButtonOpensTheHooksSheetAndPickingOneChangesTheOpening() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let hook = app.buttons["page.hookButton"]
        XCTAssertTrue(hook.waitForExistence(timeout: 5))
        hook.tap()
        let option = element(app, "hooks.option")
        XCTAssertTrue(option.waitForExistence(timeout: 10))
        option.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Hook replaced'")).firstMatch.waitForExistence(timeout: 5))
    }

    /// The AI bar only shows over a selection, never over a caret.
    func testThePageOffersNoAIBarUntilWordsAreSelected() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        XCTAssertFalse(element(app, "page.selectionBar").exists)
    }

    func testPlatformChipOffersEveryPlatformAndChangesThePreset() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        app.buttons["page.platformChip"].tap()
        for platform in ["tiktok", "reels", "shorts", "youtube", "linkedin", "stories"] {
            XCTAssertTrue(app.buttons["destination.\(platform)"].waitForExistence(timeout: 5), "Missing \(platform)")
        }
        app.buttons["destination.linkedin"].tap()
        XCTAssertTrue(app.staticTexts["Create for LinkedIn"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["page.platformChip"].value as? String, "LinkedIn")
        // The details show the format the destination sets.
        app.buttons["page.menuButton"].tap()
        app.buttons["Script details"].tap()
        let format = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '4:5 · 1080p30'")).firstMatch
        XCTAssertTrue(format.waitForExistence(timeout: 5))
    }

    func testTheMenuLeadsToImproveDetailsAndTheFullEditor() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)

        app.buttons["page.menuButton"].tap()
        app.buttons["Improve with Cue"].tap()
        XCTAssertTrue(app.buttons["improve.tool.inMyVoice"].waitForExistence(timeout: 5))
        app.buttons["sheet.closeButton"].tap()

        app.buttons["page.menuButton"].tap()
        app.buttons["Script details"].tap()
        let type = app.buttons["details.type"]
        XCTAssertTrue(type.waitForExistence(timeout: 5))
        type.tap()
        let tutorial = app.buttons["scriptType.tutorial"]
        XCTAssertTrue(tutorial.waitForExistence(timeout: 5))
        tutorial.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Sections:'")).firstMatch.waitForExistence(timeout: 5))
    }

    // MARK: - Versions & options (the writing editor)

    func testVersionsAndOptionsOpenTheEditorAndDiscardingComesBackToThePage() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        openFullEditor(app)
        // Options › Discard changes is how writing is given up.
        app.buttons["editor.tool.options"].tap()
        let discard = app.buttons["editor.discardButton"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 5))
        app.buttons["page.backButton"].tap()
        XCTAssertTrue(element(app, "scripts.promptCard").waitForExistence(timeout: 5))
    }

    func testTheWritingBarOpensItsPanelsInTheKeyboardsPlace() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        openFullEditor(app)
        for tool in ["ai", "cues", "sections", "options"] {
            let button = app.buttons["editor.tool.\(tool)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), tool)
            button.tap()
            let panel = element(app, "editor.panel.\(tool)")
            XCTAssertTrue(panel.waitForExistence(timeout: 5), "No panel for \(tool)")
        }
        // The keyboard button puts the panel away.
        app.buttons["editor.keyboardButton"].tap()
        XCTAssertFalse(element(app, "editor.panel.options").waitForExistence(timeout: 1))
    }

    func testACueGoesIntoTheTextAndDiscardingBringsTheScriptBack() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        openFullEditor(app)
        app.buttons["editor.tool.cues"].tap()
        let cue = app.buttons["editor.cue.smile"]
        XCTAssertTrue(cue.waitForExistence(timeout: 5))
        cue.tap()
        let text = app.textViews["editor.paragraph.0"]
        XCTAssertTrue((text.value as? String)?.contains("[smile]") == true)
        app.buttons["editor.tool.options"].tap()
        app.buttons["editor.discardButton"].tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'SMILE'")).firstMatch.exists)
    }

    // MARK: - Library

    func testSwipingForMoreOffersShare() {
        let app = CueApp.launch(seeded: true)
        // The AI card sits over the list: bring the row into view first (a swipe doesn't scroll to it).
        let row = app.scriptRow(Self.lamp)
        row.swipeLeft()
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let share = app.buttons["Share"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
    }

    func testSelectingAndDeleting() {
        let app = CueApp.launch(seeded: true)
        let select = app.buttons["scripts.selectButton"]
        XCTAssertTrue(select.waitForExistence(timeout: 15))
        select.tap()
        app.scriptRow(Self.lamp).tap()
        app.buttons["scripts.deleteSelectionButton"].tap()
        XCTAssertTrue(app.staticTexts["1 deleted"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts[Self.lamp].exists)
    }

    // MARK: - Helpers

    private func openScript(_ app: XCUIApplication, _ title: String) {
        app.openScriptPage(titled: title)
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 5))
    }

    /// ••• › Versions & options: the writing editor with its bar of tools.
    private func openFullEditor(_ app: XCUIApplication) {
        app.buttons["page.menuButton"].tap()
        app.buttons["Versions & options"].tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 5))
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
