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
        XCTAssertTrue(element(app, "scripts.group.ready").waitForExistence(timeout: 15))
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
        // The search is a field at the top of the list, always there.
        let field = app.scriptsSearchField
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("zzzzzz")
        XCTAssertTrue(element(app, "scripts.empty").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "scripts.group.ready").exists)
        try capture(app, "3.2f_no_results")
        app.buttons["scripts.empty.action"].tap()
        XCTAssertTrue(element(app, "scripts.group.ready").waitForExistence(timeout: 5))
    }

    /// The search is a field at the top of the list, always there, and the dock stays while searching: typing narrows the list, and the
    /// field's ✕ gives the whole list back.
    func testTheSearchIsAlwaysThereAndTheDockStays() {
        let app = CueApp.launch(seeded: true)
        let dock = element(app, "scripts.promptCard")
        XCTAssertTrue(dock.waitForExistence(timeout: 15))
        let field = app.scriptsSearchField
        XCTAssertTrue(field.exists, "the search is there without opening anything")
        XCTAssertTrue(app.navigationBars.buttons["scripts.newButton"].exists)
        XCTAssertFalse(app.navigationBars.buttons["Search"].exists, "no magnifier in the bar")
        let draft = app.staticTexts["Cold showers: one month in"]
        XCTAssertTrue(draft.exists)

        field.tap()
        field.typeText("Oat")
        XCTAssertTrue(app.staticTexts["Oat & Co. — sponsored read"].waitForExistence(timeout: 5))
        XCTAssertFalse(draft.exists)
        XCTAssertTrue(dock.exists, "the dock stays while searching")

        element(app, "scripts.search").buttons["Clear search"].tap()
        XCTAssertTrue(draft.waitForExistence(timeout: 5), "the whole list is back")
        XCTAssertTrue(dock.exists)
    }

    func testTheFirstVisitInvitesWithIdeasAndTwoWaysIn() throws {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(element(app, "empty.promptCard").waitForExistence(timeout: 15))
        XCTAssertTrue(element(app, "empty.writeButton").exists)
        XCTAssertTrue(element(app, "empty.importButton").exists)
        let ideas = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'empty.idea.'"))
        XCTAssertEqual(ideas.count, 3)
        // The Logbook is in the bar and Format on the card from the first visit on, not only after the first script.
        XCTAssertTrue(app.buttons["scripts.logbookButton"].exists, "No Logbook on the empty Scripts")
        XCTAssertTrue(app.buttons["ideaCard.formatChip"].exists, "No Format on the empty Scripts' card")
        try capture(app, "3.1_first_visit")
    }

    func testWithoutAppleIntelligenceTheCardSaysWriteItAndOpensADraft() throws {
        let app = CueApp.launch(seeded: false, ai: .none)
        let submit = app.buttons["ideaCard.submit"]
        XCTAssertTrue(submit.waitForExistence(timeout: 15))
        XCTAssertEqual(submit.label, "Write it")
        XCTAssertFalse(app.buttons["ideaCard.voiceChip"].exists, "nothing on the card is violet without Apple Intelligence")
        try capture(app, "3.1_no_ai")
        let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
        field.tap()
        field.typeText("My morning routine")
        submit.tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 10) || app.textFields["page.titleField"].waitForExistence(timeout: 10))
    }

    func testTappingAnIdeaWithAppleIntelligenceWritesIt() throws {
        let app = CueApp.launch(seeded: false)
        let first = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'empty.idea.'")).firstMatch
        XCTAssertTrue(first.waitForExistence(timeout: 15))
        first.tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 15))
    }
}

/// The creation sheets of phase 3 (+, format, brand brief, import, logbook): each opens, shows what the map says, and
/// can be captured (`TEST_RUNNER_CUE_SCREENSHOT_DIR`).
@MainActor
final class CreationSheetsUITests: XCTestCase {
    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testStartAVideoOffersSixWays() throws {
        let app = CueApp.launch(seeded: true)
        app.buttons["scripts.newButton"].tap()
        for id in ["newScript.letCue", "newScript.write", "newScript.format", "newScript.import", "newScript.answer", "newScript.freestyle"] {
            XCTAssertTrue(element(app, id).waitForExistence(timeout: 5), "No \(id)")
        }
        try capture(app, "3.5_start_a_video")
    }

    func testWithoutAppleIntelligenceLetCueWriteItIsNotOffered() {
        let app = CueApp.launch(seeded: true, ai: .none)
        app.buttons["scripts.newButton"].tap()
        XCTAssertTrue(element(app, "newScript.write").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "newScript.letCue").exists)
    }

    func testTheFormatSheetHasTilesAndOpensABlankDraft() throws {
        let app = CueApp.launch(seeded: true)
        app.buttons["scripts.newButton"].tap()
        element(app, "newScript.format").tap()
        XCTAssertTrue(element(app, "format.startSheet").waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "format.auto").exists, "Starting from a format has no Auto")
        XCTAssertTrue(element(app, "format.talking").exists)
        XCTAssertTrue(element(app, "format.mythFact").exists)
        try capture(app, "F_format_start")
        element(app, "format.tutorial").tap()
        element(app, "format.confirm").tap()
        XCTAssertTrue(app.pageBackButton.waitForExistence(timeout: 10) || app.textFields["page.titleField"].waitForExistence(timeout: 10))
    }

    func testTheCardsFormatSheetHasAutoAndSetsTheChip() throws {
        let app = CueApp.launch(seeded: true)
        app.buttons["ideaCard.formatChip"].tap()
        XCTAssertTrue(element(app, "format.sheet").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "format.auto").exists)
        try capture(app, "F_format_card")
        element(app, "format.review").tap()
        element(app, "format.confirm").tap()
        XCTAssertTrue(app.buttons["ideaCard.formatChip"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["ideaCard.formatChip"].label, "Format, Review")
    }

    func testTheBrandBriefNeedsABrandAndAProduct() throws {
        let app = CueApp.launch(seeded: true)
        app.buttons["ideaCard.formatChip"].tap()
        element(app, "format.ad").tap()
        element(app, "format.confirm").tap()
        XCTAssertTrue(element(app, "brandBrief.sheet").waitForExistence(timeout: 5))
        try capture(app, "B_brand_brief")
        // With nothing filled in, the button explains instead of writing.
        element(app, "brandBrief.confirm").tap()
        XCTAssertTrue(app.staticTexts["Add brand and product"].waitForExistence(timeout: 3))
        let brand = app.textFields["brandBrief.name"]
        brand.tap(); brand.typeText("Oat & Co.")
        let product = app.textFields["brandBrief.product"]
        product.tap(); product.typeText("Barista oat milk")
        element(app, "brandBrief.confirm").tap()
        // The ad is written into a new script page.
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 15))
    }

    func testImportReviewsTheTextBeforeUsingIt() throws {
        let app = CueApp.launch(seeded: true)
        app.buttons["scripts.newButton"].tap()
        element(app, "newScript.import").tap()
        XCTAssertTrue(element(app, "import.sheet").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["import.use"].isEnabled, "Nothing to use yet")
        try capture(app, "I_import")
        let editor = element(app, "import.editor")
        editor.tap()
        editor.typeText("Okay, real talk. Save this for payday.")
        XCTAssertTrue(app.buttons["import.use"].isEnabled)
        app.buttons["import.use"].tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 10))
    }

    func testTheLogbookWritesAnIdeaAndShowsItsEmptyState() throws {
        let app = CueApp.launch(seeded: true)
        app.buttons["scripts.logbookButton"].tap()
        XCTAssertTrue(element(app, "logbook.empty").waitForExistence(timeout: 5))
        try capture(app, "3.6_logbook_empty")
        let field = app.textFields["logbook.field"]
        field.tap(); field.typeText("A video about slow mornings\n")
        XCTAssertTrue(app.buttons["logbook.write"].waitForExistence(timeout: 5))
    }
}
