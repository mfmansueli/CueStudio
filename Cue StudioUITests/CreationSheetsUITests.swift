//
//  CreationSheetsUITests.swift
//  Cue StudioUITests
//

import XCTest

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
        let sheet = element(app, "format.sheet")
        XCTAssertTrue(sheet.waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "format.auto").exists)
        // Full height, like the dock's other sheets (the platform, My Cue Voice, Find inspiration): no half-height stop.
        XCTAssertLessThan(sheet.frame.minY, app.windows.firstMatch.frame.height * 0.2, "The format sheet opens at full height")
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
        // A field that grows with the idea (a text view to the tests); Return saves it.
        let field = element(app, "logbook.field")
        field.tap()
        try capture(app, "3.6_logbook_focused")
        field.typeText("A video about slow mornings")
        try capture(app, "3.6_logbook_typing")
        field.typeText("\n")
        XCTAssertTrue(app.buttons["logbook.write"].waitForExistence(timeout: 5))
        try capture(app, "3.6_logbook_saved")
        // Done is in the navigation bar.
        XCTAssertTrue(app.navigationBars.buttons["logbook.doneButton"].exists)
    }

    /// Typing, the button beside the field is the microphone while it is empty and the arrow that saves once there are words (as in
    /// Messages): where to confirm is never in doubt.
    func testTheButtonBesideTheFieldSavesWhatWasTyped() {
        let app = CueApp.launch(seeded: true)
        app.buttons["scripts.logbookButton"].tap()
        let field = element(app, "logbook.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        XCTAssertTrue(app.buttons["logbook.compactMic"].waitForExistence(timeout: 5), "No microphone beside the empty field")
        field.typeText("Tiny desk setups")
        let save = app.buttons["logbook.save"]
        XCTAssertTrue(save.waitForExistence(timeout: 5), "The button beside the field didn't become Save")
        save.tap()
        XCTAssertTrue(element(app, "logbook.entry").waitForExistence(timeout: 5), "The typed idea didn't reach the Logbook")
        XCTAssertTrue(app.buttons["logbook.compactMic"].waitForExistence(timeout: 5), "The field didn't empty for the next idea")
    }

    /// An idea swiped to the left is deleted, the system's way.
    func testSwipingAnIdeaInTheLogbookDeletesIt() {
        let app = CueApp.launch(seeded: true)
        app.buttons["scripts.logbookButton"].tap()
        let field = element(app, "logbook.field")
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap(); field.typeText("Swipe me away\n")
        let entry = element(app, "logbook.entry")
        XCTAssertTrue(entry.waitForExistence(timeout: 5))
        // The keyboard stays up for the next idea, and the one just saved comes into view above it.
        let visible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: entry)
        XCTAssertEqual(XCTWaiter.wait(for: [visible], timeout: 5), .completed, "The saved idea is under the keyboard")
        entry.swipeLeft()
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        XCTAssertTrue(element(app, "logbook.empty").waitForExistence(timeout: 5))
    }
}
