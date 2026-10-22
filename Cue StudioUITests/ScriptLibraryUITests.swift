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
        XCTAssertTrue(element(app, "scripts.summary").exists(within: 15))
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
        XCTAssertTrue(app.buttons["scripts.filter.reels"].exists(within: 15))
        app.buttons["scripts.filter.reels"].tap()
        XCTAssertTrue(app.scriptRow(Self.lamp).exists)
        XCTAssertFalse(app.staticTexts["Oat & Co. — sponsored read"].exists)
    }

    /// The AI dock is fixed at the bottom, above the tab bar. Selecting scripts and searching take it away (the selection bar and the
    /// keyboard have the screen); a filter does not.
    func testTheDockStaysAtTheBottomAndGivesWayToSelectionAndSearch() {
        let app = CueApp.launch(seeded: true)
        let prompt = element(app, "scripts.promptCard")
        XCTAssertTrue(prompt.exists(within: 15))
        XCTAssertGreaterThan(prompt.frame.minY, app.frame.height / 2, "the dock is at the bottom")

        app.buttons["scripts.selectButton"].tap()
        XCTAssertFalse(prompt.exists(within: 1))
        app.buttons["scripts.selectButton"].tap()
        XCTAssertTrue(prompt.exists(within: 5))

        let search = app.openScriptsSearch(timeout: 5)
        search.typeText("nothing matches this")
        XCTAssertTrue(element(app, "scripts.empty").exists(within: 5))
        XCTAssertTrue(prompt.exists, "the dock stays while searching")
    }

    /// A folder made from Select, then deleted from its chip (held): the chip goes, the script stays in All, and Undo brings the
    /// folder back.
    func testAFolderIsDeletedFromItsChipAndItsScriptsStay() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.buttons["scripts.selectButton"].exists(within: 15))
        app.buttons["scripts.selectButton"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.'"))
        XCTAssertTrue(rows.firstMatch.exists(within: 5))
        let rowCount = rows.count
        rows.element(boundBy: 0).tap()
        app.buttons["Move to folder"].tap()
        let newFolder = app.buttons["New folder…"]
        XCTAssertTrue(newFolder.exists(within: 5))
        newFolder.tap()
        let field = app.alerts.textFields.firstMatch
        XCTAssertTrue(field.exists(within: 5), "No folder name field")
        field.typeText("Brand deals")
        app.alerts.buttons["Create"].tap()

        let chip = app.buttons["scripts.filter.folder.Brand deals"]
        XCTAssertTrue(chip.exists(within: 5), "No chip for the new folder")
        // The new folder's chip ends the sideways row: brought into the window.
        let chips = app.descendants(matching: .any)["scripts.filters"]
        let window = app.windows.firstMatch.frame
        for _ in 0..<4 where !window.contains(chip.frame) { chips.swipeLeft() }
        chip.waitUntilStill()
        chip.press(forDuration: 1)
        let delete = app.buttons["scripts.filter.deleteFolder"]
        XCTAssertTrue(delete.exists(within: 5), "No Delete folder on the chip")
        delete.tap()
        XCTAssertTrue(chip.isGone(within: 5), "The folder is still there")
        XCTAssertTrue(app.staticTexts["Folder deleted"].exists(within: 3), "No word that the folder went")
        XCTAssertEqual(rows.count, rowCount, "Deleting the folder took a script with it")

        let undo = app.buttons["Undo"].firstMatch
        XCTAssertTrue(undo.exists(within: 3))
        undo.tap()
        XCTAssertTrue(chip.exists(within: 5), "Undo didn't bring the folder back")
    }

    /// Select: a tap on a row picks the script (its mark is drawn inside the card) and a second lets it go; no swipe while selecting.
    func testSelectingPicksScriptsWithATapOnTheirRow() throws {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.buttons["scripts.selectButton"].exists(within: 15))
        app.buttons["scripts.selectButton"].tap()
        let rows = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.'"))
        XCTAssertTrue(rows.firstMatch.exists(within: 5))
        let first = rows.element(boundBy: 0), second = rows.element(boundBy: 1)
        XCTAssertFalse(first.isSelected)
        XCTAssertTrue(app.staticTexts["Select scripts"].exists)
        first.tap()
        second.tap()
        XCTAssertTrue(first.isSelected && second.isSelected)
        XCTAssertTrue(app.staticTexts["2 selected"].exists(within: 2))
        if let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] {
            let directory = URL(fileURLWithPath: folder, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "scripts-selecting.png"))
        }
        first.tap()
        XCTAssertFalse(first.isSelected)
        XCTAssertTrue(app.staticTexts["1 selected"].exists(within: 2))
        first.swipeLeft()
        XCTAssertFalse(app.buttons["Record"].exists, "No swipe actions while selecting")
        XCTAssertFalse(app.pageBackButton.exists, "A tap while selecting doesn't open the script")
    }

    func testTheCardsArrowWritesTheIdeaIntoANewPage() {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 15))
        field.tap()
        field.typeText("A day in my life")
        app.buttons["ideaCard.submit"].tap()
        // The page opens and the words arrive on it, in the Draft; the card is empty again.
        XCTAssertTrue(app.pageBackButton.exists(within: 10))
        XCTAssertTrue(element(app, "page.editor").exists(within: 10))
        XCTAssertTrue((element(app, "page.editor").value as? String)?.contains("Save this for later") == true)
        XCTAssertEqual((element(app, "page.titleField").value as? String), "A day in my life")
        app.pageBackButton.tap()
        XCTAssertTrue(element(app, "ideaCard.field").exists(within: 5))
        XCTAssertNotEqual(element(app, "ideaCard.field").value as? String, "A day in my life")
    }

    func testAnimatedPromptKeepsItsFrameAndAction() {
        let app = CueApp.launch(seeded: true)
        let prompt = element(app, "scripts.promptCard")
        XCTAssertTrue(prompt.exists(within: 15))
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
        XCTAssertTrue(app.keyboards.firstMatch.exists(within: 5))
        XCTAssertFalse(app.pageBackButton.exists)
    }

    func testSearch() {
        let app = CueApp.launch(seeded: true)
        let search = app.openScriptsSearch()
        search.typeText("Q&A")
        XCTAssertTrue(app.staticTexts["Weekly Q&A — episode 12"].exists(within: 5))
        XCTAssertFalse(app.staticTexts[Self.lamp].exists)
    }

    // MARK: - Navigation

    func testSavingAnExistingScriptAndReopeningItStillNeedsOnlyOneBackTap() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.exists(within: 5))
        text.tap()
        text.typeText(" Updated for navigation testing.")
        app.pageBackButton.tap()
        XCTAssertTrue(element(app, "scripts.promptCard").exists(within: 5))
        XCTAssertFalse(app.buttons["detail.recordButton"].exists)

        // Saving promotes this row to the one edited last, but must not create another page.
        openScript(app, Self.lamp)
        app.pageBackButton.tap()
        XCTAssertTrue(element(app, "scripts.promptCard").exists(within: 5))
        XCTAssertFalse(app.buttons["detail.recordButton"].exists)
    }

    func testDifferentScriptsAndRepeatedOpensDoNotAccumulatePages() {
        let app = CueApp.launch(seeded: true)
        for title in [Self.habits, Self.lamp, Self.habits] {
            openScript(app, title)
            XCTAssertTrue(app.staticTexts[title].exists || (element(app, "page.titleField").value as? String) == title)
            app.pageBackButton.tap()
            XCTAssertTrue(element(app, "scripts.promptCard").exists(within: 5))
            XCTAssertFalse(app.buttons["detail.recordButton"].exists)
        }
    }

    /// A script that already has takes opens its page with a tap on the row, like any other; its "×3 ›" is the way to its videos.
    func testARecordedScriptOpensItsPageAndItsCountGoesToTakes() {
        let app = CueApp.launch(seeded: true)
        let row = app.scriptRow(Self.habits)
        row.tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].exists(within: 5), "the row opens the script's page")
        // The page hides the tab bar (`hidesTabBar`): back on the list it is there again, still on Scripts.
        app.pageBackButton.tap()
        XCTAssertTrue(element(app, "scripts.promptCard").exists(within: 5))
        XCTAssertTrue(app.cueTabBar.buttons["Scripts"].exists(within: 5))
        XCTAssertTrue(app.cueTabBar.buttons["Scripts"].isSelected, "the row didn't leave Scripts")

        let count = app.buttons["row.takes"].firstMatch
        XCTAssertTrue(count.exists(within: 5), "a recorded row has its ×n button")
        count.tap()
        XCTAssertTrue(element(app, "takes.pipeline").exists(within: 5), "×3 › goes to Takes")
        XCTAssertFalse(app.pageBackButton.exists)
    }

    func testNewScriptOpensInTheDraftWithTheTitleReady() {
        let app = CueApp.launch(seeded: true)
        let plus = app.buttons["scripts.newButton"]
        XCTAssertTrue(plus.exists(within: 15))
        plus.tap()
        let write = app.buttons["newScript.write"]
        XCTAssertTrue(write.exists(within: 5))
        write.tap()
        let title = element(app, "page.titleField")
        XCTAssertTrue(title.exists(within: 5))
        XCTAssertTrue(element(app, "page.editor").exists)
        title.typeText("One-tap navigation script")
        app.pageBackButton.tap()
        XCTAssertTrue(element(app, "scripts.promptCard").exists(within: 5))
        XCTAssertFalse(app.buttons["detail.recordButton"].exists)
        // A blank draft opens straight into writing (Continue ›), with the keyboard up.
        app.staticTexts["One-tap navigation script"].tap()
        XCTAssertTrue(app.pageBackButton.exists(within: 5))
        app.pageBackButton.tap()
        XCTAssertTrue(element(app, "scripts.promptCard").exists(within: 5))
        XCTAssertFalse(app.pageBackButton.exists)
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
            XCTAssertTrue(close.exists(within: 10))
            close.tap()
            XCTAssertTrue(app.buttons["detail.recordButton"].exists(within: 5))
            app.pageBackButton.tap()
            XCTAssertTrue(element(app, "scripts.promptCard").exists(within: 5))
            XCTAssertFalse(app.buttons["detail.recordButton"].exists)
        }
    }

    // MARK: - The page

    func testThePageHasTheStripTheLengthAndExactlyOneRecordButton() {
        let app = CueApp.launch(seeded: true)
        openScript(app, "Oat & Co. — sponsored read")
        XCTAssertTrue(element(app, "page.strip").exists(within: 5))
        XCTAssertTrue(element(app, "page.lengthBar").exists)
        XCTAssertTrue((element(app, "page.lengthBar").value as? String)?.localizedCaseInsensitiveContains("words") == true)
        XCTAssertTrue(element(app, "page.editor").exists)
        // The Draft | Shaped switch is gone; Record is the page's only one.
        XCTAssertFalse(app.buttons["page.mode.draft"].exists || app.buttons["page.mode.shaped"].exists)
        XCTAssertEqual(app.buttons.matching(identifier: "detail.recordButton").count, 1)
        // Record stays at hand while the title is being typed (only the words' keyboard brings the cues in its place).
        element(app, "page.titleField").tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].exists(within: 5))
        XCTAssertTrue(app.buttons["detail.recordButton"].isHittable)
    }

    func testACueFromTheBarGoesIntoTheText() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.exists(within: 5))
        text.tap()
        XCTAssertTrue(element(app, "page.cuesBar").exists(within: 5))
        app.buttons["page.cue.pause"].tap()
        XCTAssertTrue((text.value as? String)?.contains("[pause]") == true)
    }

    /// Cues, by Improve, hides the cue tags on the page and shows them again; the words keep them either way.
    func testTheCuesSwitchHidesAndShowsTheTags() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let toggle = element(app, "page.cuesToggle")
        XCTAssertTrue(toggle.exists(within: 5))
        let state = { (toggle.value as? String) ?? String(toggle.isSelected) }
        let before = state()
        toggle.tap()
        XCTAssertNotEqual(state(), before)
        XCTAssertTrue((element(app, "page.editor").value as? String)?.contains("[pause]") == true)
        toggle.tap()
        XCTAssertEqual(state(), before)
    }

    /// Backspace into a cue takes the whole tag; "+" on the bar makes a cue of the creator's own, which stays on the bar.
    func testDeletingIntoACueDeletesAllOfItAndANewCueStaysOnTheBar() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.exists(within: 5))
        text.tap()
        // Smile: the sample script has no smile of its own (it has a [pause]).
        XCTAssertTrue(app.buttons["page.cue.smile"].exists(within: 5))
        app.buttons["page.cue.smile"].tap()
        XCTAssertTrue((text.value as? String)?.contains("[smile]") == true)
        // The cue went in with a space after it: the first backspace takes the space, the second the whole cue.
        text.typeText(XCUIKeyboardKey.delete.rawValue)
        text.typeText(XCUIKeyboardKey.delete.rawValue)
        let afterDelete = text.value as? String ?? ""
        XCTAssertFalse(afterDelete.contains("smile") || afterDelete.contains("[smil"), "A piece of the cue stayed: \(afterDelete)")

        app.buttons["page.addCueButton"].tap()
        let alert = app.alerts["New cue"]
        XCTAssertTrue(alert.exists(within: 5))
        alert.textFields.firstMatch.typeText("laugh")
        alert.buttons["Add"].tap()
        XCTAssertTrue(app.buttons["page.cue.laugh"].exists(within: 5))
        XCTAssertTrue((text.value as? String)?.contains("[laugh]") == true)
    }

    func testTheHookButtonOpensTheHooksSheetAndPickingOneChangesTheOpening() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let hook = app.buttons["page.hookButton"]
        XCTAssertTrue(hook.exists(within: 5))
        hook.tap()
        let option = element(app, "hooks.option")
        XCTAssertTrue(option.exists(within: 10))
        option.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Hook replaced'")).firstMatch.exists(within: 5))
    }

    /// The AI bar only shows over a selection, never over a caret.
    func testThePageOffersNoAIBarUntilWordsAreSelected() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.exists(within: 5))
        text.tap()
        XCTAssertFalse(element(app, "page.selectionBar").exists)
    }

    func testPlatformChipOffersEveryPlatformAndChangesThePreset() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)
        app.buttons["page.platformChip"].tap()
        for platform in ["tiktok", "reels", "shorts", "youtube", "linkedin", "stories"] {
            XCTAssertTrue(app.buttons["destination.\(platform)"].exists(within: 5), "Missing \(platform)")
        }
        let linkedIn = app.buttons["destination.linkedin"]
        linkedIn.waitUntilStill()
        linkedIn.tap()
        XCTAssertTrue(app.staticTexts["Create for LinkedIn"].exists(within: 10), "Picking LinkedIn didn't set the page for it")
        XCTAssertEqual(app.buttons["page.platformChip"].value as? String, "LinkedIn")
        // The details show the format the destination sets.
        app.buttons["page.menuButton"].tap()
        let details = app.buttons["Script details"]
        XCTAssertTrue(details.exists(within: 5), "No Script details in the menu")
        details.tap()
        let format = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '4:5 · 1080p30'")).firstMatch
        XCTAssertTrue(format.exists(within: 10), "The details don't show LinkedIn's format")
    }

    func testImproveIsOnThePageAndTheMenuLeadsToDetails() {
        let app = CueApp.launch(seeded: true)
        openScript(app, Self.lamp)

        // Improve is on the page itself, and the menu doesn't repeat it.
        app.buttons["page.improveButton"].tap()
        XCTAssertTrue(app.buttons["improve.tool.inMyVoice"].exists(within: 5))
        app.buttons["sheet.closeButton"].tap()

        app.buttons["page.menuButton"].tap()
        XCTAssertTrue(app.buttons["Script details"].exists(within: 5))
        XCTAssertFalse(app.buttons["Improve with Cue"].exists)
        // The old full editor is gone: the page is where the words are written.
        XCTAssertFalse(app.buttons["Versions & options"].exists)
        app.buttons["Script details"].tap()
        let type = app.buttons["details.type"]
        XCTAssertTrue(type.exists(within: 5))
        type.tap()
        let tutorial = app.buttons["scriptType.tutorial"]
        XCTAssertTrue(tutorial.exists(within: 5))
        tutorial.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Sections:'")).firstMatch.exists(within: 5))
    }

    // MARK: - Library

    func testSwipingForMoreOffersShare() {
        let app = CueApp.launch(seeded: true)
        // The AI card sits over the list: bring the row into view first (a swipe doesn't scroll to it).
        let row = app.scriptRow(Self.lamp)
        row.swipeLeft()
        let more = app.buttons["More"]
        XCTAssertTrue(more.exists(within: 5))
        more.tap()
        let share = app.buttons["Share"]
        XCTAssertTrue(share.exists(within: 5))
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].exists(within: 5))
    }

    func testSelectingAndDeleting() {
        let app = CueApp.launch(seeded: true)
        let select = app.buttons["scripts.selectButton"]
        XCTAssertTrue(select.exists(within: 15))
        select.tap()
        app.scriptRow(Self.lamp).tap()
        app.buttons["scripts.deleteSelectionButton"].tap()
        XCTAssertTrue(app.staticTexts["1 deleted"].exists(within: 5))
        XCTAssertFalse(app.staticTexts[Self.lamp].exists)
    }

    // MARK: - Helpers

    private func openScript(_ app: XCUIApplication, _ title: String) {
        app.openScriptPage(titled: title)
        XCTAssertTrue(app.buttons["detail.recordButton"].exists(within: 5))
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
