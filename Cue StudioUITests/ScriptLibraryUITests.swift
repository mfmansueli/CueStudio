//
//  ScriptLibraryUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Browsing, filtering, opening and editing scripts.
@MainActor
final class ScriptLibraryUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testHeroShowsTheLastEditedScript() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.staticTexts["3 morning habits that changed my life"].waitForExistence(timeout: 15))
        XCTAssertTrue(app.buttons["hero.recordButton"].exists)
        XCTAssertTrue(app.buttons["hero.studioButton"].exists)
    }

    func testFilteringByDestination() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.staticTexts["Unboxing the Lumen desk lamp"].waitForExistence(timeout: 15))
        app.buttons["Reels"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["Unboxing the Lumen desk lamp"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Oat & Co. — sponsored read"].exists)
    }

    func testPromptBoxStaysOnTop() {
        let app = CueApp.launch(seeded: true)
        let prompt = app.buttons["scripts.promptCard"]
        XCTAssertTrue(prompt.waitForExistence(timeout: 15))
        let search = app.descendants(matching: .any)["scripts.searchField"].firstMatch
        XCTAssertLessThan(prompt.frame.minY, search.frame.minY)

        // No filter, search or selection hides it.
        app.buttons["scripts.selectButton"].tap()
        XCTAssertTrue(prompt.exists)
        app.buttons["scripts.selectButton"].tap()
        search.tap()
        search.typeText("nothing matches this")
        XCTAssertTrue(app.staticTexts["No scripts here yet."].waitForExistence(timeout: 5))
        XCTAssertTrue(prompt.exists)

        prompt.tap()
        XCTAssertTrue(app.descendants(matching: .any)["generate.promptField"].firstMatch.waitForExistence(timeout: 5))
    }

    func testAnimatedPromptKeepsItsFrameAndAction() {
        let app = CueApp.launch(seeded: true)
        let prompt = app.buttons["scripts.promptCard"]
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

        prompt.tap()
        XCTAssertTrue(app.descendants(matching: .any)["generate.promptField"].firstMatch.waitForExistence(timeout: 5))
    }

    func testSearch() {
        let app = CueApp.launch(seeded: true)
        let search = app.descendants(matching: .any)["scripts.searchField"].firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 15))
        search.tap()
        search.typeText("Q&A")
        XCTAssertTrue(app.staticTexts["Weekly Q&A — episode 12"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Unboxing the Lumen desk lamp"].exists)
    }

    func testOpeningAndDiscardingAnEdit() {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()

        let edit = app.buttons["detail.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 5))
        // Options › Discard changes is how writing is given up.
        app.buttons["editor.tool.options"].tap()
        let discard = app.buttons["editor.discardButton"]
        XCTAssertTrue(discard.waitForExistence(timeout: 5))
        discard.tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["scripts.promptCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(edit.exists)
    }

    func testExistingScriptReturnsToScriptsWithOneBackTap() {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        XCTAssertTrue(app.buttons["detail.editButton"].waitForExistence(timeout: 5))
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), app.navigationBars.debugDescription)
        back.tap()
        XCTAssertTrue(app.buttons["scripts.promptCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["detail.editButton"].exists)
    }

    func testHeroScriptReturnsToScriptsWithOneBackTap() {
        let app = CueApp.launch(seeded: true)
        let hero = app.staticTexts["3 morning habits that changed my life"]
        XCTAssertTrue(hero.waitForExistence(timeout: 15))
        hero.tap()
        XCTAssertTrue(app.buttons["detail.editButton"].waitForExistence(timeout: 5))
        let back = app.navigationBars.buttons.firstMatch
        XCTAssertTrue(back.waitForExistence(timeout: 5), app.navigationBars.debugDescription)
        back.tap()
        XCTAssertTrue(app.buttons["scripts.promptCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["detail.editButton"].exists)
        app.buttons["scripts.selectButton"].tap()
        let deleteSelection = app.buttons["scripts.deleteSelectionButton"]
        XCTAssertTrue(deleteSelection.waitForExistence(timeout: 5))
        app.buttons["scripts.selectButton"].tap()
        XCTAssertTrue(app.buttons["scripts.promptCard"].exists)
    }

    func testSavingAnExistingScriptAndReopeningItStillNeedsOnlyOneBackTap() {
        let app = CueApp.launch(seeded: true)
        let title = "Unboxing the Lumen desk lamp"
        let row = app.staticTexts[title]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        let edit = app.buttons["detail.editButton"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        let text = app.textViews["editor.paragraph.0"]
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText(" Updated for navigation testing.")
        app.buttons["editor.doneButton"].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["scripts.promptCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(edit.exists)

        // Saving promotes this row to the hero, but must not create another detail destination.
        app.staticTexts[title].tap()
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["scripts.promptCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(edit.exists)
    }

    func testDifferentScriptsAndRepeatedOpensDoNotAccumulateDetailScreens() {
        let app = CueApp.launch(seeded: true)
        for title in ["3 morning habits that changed my life", "Unboxing the Lumen desk lamp", "3 morning habits that changed my life"] {
            let script = app.staticTexts[title]
            XCTAssertTrue(script.waitForExistence(timeout: 15))
            script.tap()
            XCTAssertTrue(app.buttons["detail.editButton"].waitForExistence(timeout: 5))
            XCTAssertTrue(app.staticTexts[title].exists)
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["scripts.promptCard"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["detail.editButton"].exists)
        }
    }

    func testNewScriptAndItsReopenedDetailReturnWithOneBackTap() {
        let app = CueApp.launch(seeded: true)
        let plus = app.buttons["scripts.newButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()
        let write = app.buttons["newScript.write"]
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        write.tap()
        let title = app.descendants(matching: .any)["editor.titleField"].firstMatch
        XCTAssertTrue(title.waitForExistence(timeout: 5))
        title.tap()
        title.typeText("One-tap navigation script")
        app.buttons["editor.doneButton"].tap()
        XCTAssertTrue(app.buttons["detail.editButton"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["scripts.promptCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["detail.editButton"].exists)
        app.staticTexts["One-tap navigation script"].tap()
        XCTAssertTrue(app.buttons["detail.editButton"].waitForExistence(timeout: 5))
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["scripts.promptCard"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["detail.editButton"].exists)
    }

    func testStudioAndRecordReturnToTheSameDetailWithoutAddingAnotherRoute() {
        let app = CueApp.launch(seeded: true)
        for action in ["detail.studioButton", "detail.recordButton"] {
            let hero = app.staticTexts["3 morning habits that changed my life"]
            XCTAssertTrue(hero.waitForExistence(timeout: 15))
            hero.tap()
            let launch = app.buttons[action]
            XCTAssertTrue(launch.waitForExistence(timeout: 5))
            launch.tap()
            let close = app.buttons["prompter.closeButton"]
            XCTAssertTrue(close.waitForExistence(timeout: 10))
            close.tap()
            XCTAssertTrue(app.buttons["detail.editButton"].waitForExistence(timeout: 5))
            app.navigationBars.buttons.firstMatch.tap()
            XCTAssertTrue(app.buttons["scripts.promptCard"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.buttons["detail.editButton"].exists)
        }
    }

    func testDestinationSheetChangesThePreset() {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()

        app.buttons["detail.summaryRow"].tap()
        let destination = app.buttons["details.destination"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.tap()
        let youtube = app.buttons.containing(NSPredicate(format: "label CONTAINS 'YouTube · long-form'")).firstMatch
        XCTAssertTrue(youtube.waitForExistence(timeout: 5))
        youtube.tap()
        // The details show the format the destination sets.
        app.buttons["detail.summaryRow"].tap()
        let format = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS '16:9 · 4K24'")).firstMatch
        XCTAssertTrue(format.waitForExistence(timeout: 5))
    }

    func testSwipingForMoreOffersShare() {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.swipeLeft()
        let more = app.buttons["More"]
        XCTAssertTrue(more.waitForExistence(timeout: 5))
        more.tap()
        let share = app.buttons["Share"]
        XCTAssertTrue(share.waitForExistence(timeout: 5))
        share.tap()
        XCTAssertTrue(app.otherElements["ActivityListView"].waitForExistence(timeout: 5))
    }

    func testTappingAParagraphStartsEditingThere() {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()
        let text = app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", "it folds flat")).firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 5))
    }

    func testCreateForOffersEveryPlatform() {
        let app = CueApp.launch(seeded: true)
        let row = app.staticTexts["Unboxing the Lumen desk lamp"]
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        row.tap()

        // The summary line opens the details, where "Create for" is the first row.
        app.buttons["detail.summaryRow"].tap()
        let destination = app.buttons["details.destination"]
        XCTAssertTrue(destination.waitForExistence(timeout: 5))
        destination.tap()
        for platform in ["tiktok", "reels", "shorts", "youtube", "linkedin", "stories"] {
            XCTAssertTrue(app.buttons["destination.\(platform)"].waitForExistence(timeout: 5), "Missing \(platform)")
        }
        app.buttons["destination.linkedin"].tap()
        XCTAssertTrue(app.staticTexts["Create for LinkedIn"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["4:5 · 1080p30"].waitForExistence(timeout: 5))
    }

    func testSelectingAndDeleting() {
        let app = CueApp.launch(seeded: true)
        let select = app.buttons["scripts.selectButton"]
        XCTAssertTrue(select.waitForExistence(timeout: 15))
        select.tap()
        app.staticTexts["Unboxing the Lumen desk lamp"].tap()
        app.buttons["scripts.deleteSelectionButton"].tap()
        XCTAssertTrue(app.staticTexts["1 deleted"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Unboxing the Lumen desk lamp"].exists)
    }
}
