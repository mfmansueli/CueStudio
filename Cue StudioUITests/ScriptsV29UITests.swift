//
//  ScriptsV29UITests.swift
//  Cue StudioUITests
//

import XCTest

/// Scripts (v29 · 3.1 and 3.2): the groups READY TO RECORD · DRAFTS · RECORDED, the LET'S CUE! card with its chips, the
/// first visit's ideas, the filter with no results, and the card without Apple Intelligence.
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` saves a picture of each state.
@MainActor
final class ScriptsV29UITests: XCTestCase {
    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
        // The hierarchy beside the picture, for `tools/contrast/audit.py`.
        try app.debugDescription.write(to: directory.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testTheListIsGroupedByState() throws {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(element(app, "scripts.group.ready").exists(within: 15))
        XCTAssertTrue(element(app, "scripts.group.draft").exists)
        XCTAssertTrue(element(app, "scripts.group.recorded").exists)
        // A ready script has its REC pill, a draft "Continue ›", a recorded one "×n ›".
        XCTAssertTrue(app.buttons["row.recordButton"].firstMatch.exists)
        XCTAssertTrue(element(app, "row.continue").exists)
        XCTAssertTrue(element(app, "row.takes").exists)
        // The card's chips: Format, the platform and the voice.
        XCTAssertTrue(app.buttons["ideaCard.formatChip"].exists)
        XCTAssertTrue(app.buttons["ideaCard.platformChip"].exists)
        XCTAssertTrue(app.buttons["ideaCard.voiceChip"].exists)
        XCTAssertTrue(element(app, "ideaCard.anotherIdea").exists)
        try capture(app, "3.2_scripts")
    }

    func testASearchWithNoResultShowsTheEmptyStateAndTheWayOut() throws {
        let app = CueApp.launch(seeded: true)
        let field = app.openScriptsSearch()
        field.typeText("zzzzzz")
        XCTAssertTrue(element(app, "scripts.empty").exists(within: 5))
        XCTAssertFalse(element(app, "scripts.group.ready").exists)
        try capture(app, "3.2f_no_results")
        app.buttons["scripts.empty.action"].tap()
        XCTAssertTrue(element(app, "scripts.group.ready").exists(within: 5))
    }

    /// The search is the bar's magnifier, beside the Logbook and "+": it opens a field at the top of the list with the keyboard, typing narrows
    /// the list while the dock stays, the field's ✕ gives the whole list back, and the field goes once the keyboard does.
    func testTheMagnifierOpensTheSearchAndTheDockStays() {
        let app = CueApp.launch(seeded: true)
        let dock = element(app, "scripts.promptCard")
        XCTAssertTrue(dock.exists(within: 15))
        XCTAssertFalse(app.scriptsSearchField.exists, "the search waits for the magnifier")
        XCTAssertTrue(app.navigationBars.buttons["scripts.logbookButton"].exists)
        XCTAssertTrue(app.navigationBars.buttons["scripts.newButton"].exists)
        let draft = app.staticTexts["Cold showers: one month in"]
        XCTAssertTrue(draft.exists)

        let field = app.openScriptsSearch()
        field.typeText("Oat")
        XCTAssertTrue(app.staticTexts["Oat & Co. — sponsored read"].exists(within: 5))
        XCTAssertFalse(draft.exists)
        XCTAssertTrue(dock.exists, "the dock stays while searching")

        element(app, "scripts.search").buttons["Clear search"].tap()
        XCTAssertTrue(draft.exists(within: 5), "the whole list is back")
        XCTAssertTrue(dock.exists)

        // Without words, the field goes with the keyboard (a scroll sends the keyboard away).
        app.swipeDown()
        XCTAssertTrue(field.isGone(within: 5), "the empty search stayed after the keyboard went")
    }

    func testTheFirstVisitOffersItsWaysIn() throws {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(element(app, "empty.promptCard").exists(within: 15))
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists, "Find inspiration is the dock's lightbulb")
        XCTAssertTrue(element(app, "empty.writeButton").exists)
        XCTAssertTrue(element(app, "empty.importButton").exists)
        // The Logbook is in the bar and Format on the card from the first visit on, not only after the first script.
        XCTAssertTrue(app.buttons["scripts.logbookButton"].exists, "No Logbook on the empty Scripts")
        XCTAssertTrue(app.buttons["ideaCard.formatChip"].exists, "No Format on the empty Scripts' card")
        try capture(app, "3.1_first_visit")
    }

    func testWithoutAppleIntelligenceTheCardSaysWriteItAndOpensADraft() throws {
        let app = CueApp.launch(seeded: false, ai: .none)
        let submit = app.buttons["ideaCard.submit"]
        XCTAssertTrue(submit.exists(within: 15))
        XCTAssertEqual(submit.label, "Write it")
        XCTAssertFalse(app.buttons["ideaCard.voiceChip"].exists, "nothing on the card is violet without Apple Intelligence")
        try capture(app, "3.1_no_ai")
        let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
        field.tap()
        field.typeText("My morning routine")
        submit.tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].exists(within: 10) || app.textFields["page.titleField"].exists(within: 10))
    }

    func testFindInspirationFromTheFirstVisitWritesAnIdea() throws {
        let app = CueApp.launch(seeded: false)
        let inspiration = app.buttons["ideaCard.inspirationButton"]
        XCTAssertTrue(inspiration.exists(within: 15))
        inspiration.tap()
        let write = app.buttons["inspiration.writeNow"]
        XCTAssertTrue(write.exists(within: 5))
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        write.tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].exists(within: 15))
    }
}
