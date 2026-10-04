//
//  ScriptPageUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The script page (v29 · 4.1–4.4): the state strip in each state, Done, leaving with edits, "✦ Shape", the AI bar on a selection
/// and the page without Apple Intelligence. `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` saves a picture of each state.
@MainActor
final class ScriptPageUITests: XCTestCase {
    private static let ready = "Oat & Co. — sponsored read"
    private static let draft = "Cold showers: one month in"
    private static let recorded = "Unboxing the Lumen desk lamp"

    override func setUp() {
        continueAfterFailure = false
    }

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

    private func strip(_ app: XCUIApplication) -> String {
        element(app, "page.strip.info").label
    }

    func testAReadyScriptShowsReadyAndOneYellowRecord() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.ready)
        XCTAssertTrue(element(app, "page.strip").waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(NSPredicate(format: "label ==[c] 'Ready'")).firstMatch.exists)
        XCTAssertEqual(app.buttons.matching(identifier: "detail.recordButton").count, 1)
        XCTAssertEqual(app.buttons["detail.recordButton"].label, "Record")
        try capture(app, "4.1_ready")
    }

    func testADraftOpensWritingAndDoneMakesItReady() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.draft)
        XCTAssertTrue(element(app, "page.strip").waitForExistence(timeout: 5))
        try capture(app, "4.2_draft")
        // The strip says DRAFT; Done makes it READY and the words stay.
        XCTAssertTrue(app.buttons["page.doneButton"].waitForExistence(timeout: 5))
        app.buttons["page.doneButton"].tap()
        // A storytime has four sections and this one has a single line: Done asks first.
        XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
        app.alerts.buttons["Done anyway"].tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH 'Ready to record'")).firstMatch.waitForExistence(timeout: 5))
    }

    func testEditingAReadyScriptAndGoingBackMakesItADraft() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.ready)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.waitForExistence(timeout: 5))
        text.tap()
        text.typeText(" One more line.")
        XCTAssertEqual(strip(app).uppercased(), "EDITED · TAP DONE")
        app.buttons["page.backButton"].tap()
        XCTAssertTrue(app.staticTexts["Saved as draft"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "scripts.group.draft").waitForExistence(timeout: 5))
    }

    func testDoneWithNoTextSavesNothing() throws {
        let app = CueApp.launch(seeded: true)
        app.buttons["scripts.newButton"].tap()
        app.buttons["newScript.write"].tap()
        XCTAssertTrue(app.textFields["page.titleField"].waitForExistence(timeout: 10))
        app.textFields["page.titleField"].typeText("\n")
        XCTAssertTrue(app.buttons["page.doneButton"].waitForExistence(timeout: 5) || element(app, "page.cuesBar").waitForExistence(timeout: 5))
        // The cues bar is up with the keyboard; put it away to reach Done.
        element(app, "page.strip").tap()
        app.buttons["page.doneButton"].tap()
        XCTAssertTrue(app.staticTexts["Nothing to save yet"].waitForExistence(timeout: 5))
    }

    func testARecordedScriptSaysChangedSinceTheTakeAfterAnEdit() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.recorded)
        XCTAssertEqual(app.buttons["detail.recordButton"].label, "Retake")
        XCTAssertFalse(app.buttons["page.doneButton"].exists, "a recorded script has no Done")
        try capture(app, "4.1_recorded")
        let text = element(app, "page.editor")
        text.tap()
        text.typeText(" Edited after the take.")
        element(app, "page.strip").tap()
        XCTAssertTrue(strip(app).uppercased().hasPrefix("CHANGED SINCE TAKE"))
        try capture(app, "4.1_recorded_changed")
    }

    func testShapeAddsCuesToAScriptWithNone() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.draft)
        let shape = app.buttons["page.shapeButton"]
        XCTAssertTrue(shape.waitForExistence(timeout: 5))
        shape.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'cue'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(shape.waitForExistence(timeout: 2), "Shape is for scripts with no cues")
    }

    func testTheAIBarRewritesTheSelectionInPlaceAndKeepsOrUndoes() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.ready)
        let text = element(app, "page.editor")
        text.tap()
        text.press(forDuration: 1.0)
        let selectAll = app.menuItems["Select All"]
        if selectAll.waitForExistence(timeout: 3) { selectAll.tap() }
        let shorter = app.buttons["page.selection.shorter"]
        XCTAssertTrue(shorter.waitForExistence(timeout: 5), "No AI bar over a selection")
        try capture(app, "A_ai_bar")
        shorter.tap()
        XCTAssertTrue(app.buttons["page.selection.keep"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["page.selection.undo"].exists && app.buttons["page.selection.retry"].exists)
        try capture(app, "A_ai_replaced")
        app.buttons["page.selection.undo"].tap()
        XCTAssertFalse(app.buttons["page.selection.keep"].exists)
    }

    func testWithoutAppleIntelligenceThePageHasNoShapeNoImproveAndNoBar() throws {
        let app = CueApp.launch(seeded: true, ai: .none)
        app.openScriptPage(titled: Self.draft)
        XCTAssertTrue(element(app, "page.strip").waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["page.shapeButton"].exists)
        XCTAssertFalse(app.buttons["page.improveButton"].exists)
        XCTAssertTrue(app.buttons["page.hookButton"].exists)
        try capture(app, "4.1_no_ai")
    }
}
