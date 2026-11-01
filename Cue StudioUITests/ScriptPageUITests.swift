//
//  ScriptPageUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The script page (v29 · 4.1–4.4): the state strip in each state, Done, leaving with edits, "✦ Shape" in the tools row, the AI bar
/// on a selection and the page without Apple Intelligence. `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` saves a picture of each state.
@MainActor
final class ScriptPageUITests: XCTestCase {
    private static let ready = "Oat & Co. · sponsored read"
    private static let draft = "Cold showers: one month in"
    private static let recorded = "Unboxing the Lumen desk lamp"

    override func setUp() {
        continueAfterFailure = false
    }

    /// The screen as a PNG in `CUE_SCREENSHOT_DIR` (on the Simulator), and kept in the result (on the iPhone too, read back with `xcresulttool`).
    private func capture(_ app: XCUIApplication, _ name: String) throws {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// The ready switch is on ("On" as the page says it, or "1" as a toggle reports it).
    private func isOn(_ toggle: XCUIElement) -> Bool {
        let value = toggle.value as? String
        return value == "On" || value == "1"
    }

    private func strip(_ app: XCUIApplication) -> String {
        element(app, "page.strip.info").label
    }

    func testADraftBecomesReadyWithItsSwitchAndBack() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.draft)
        XCTAssertTrue(element(app, "page.strip").exists(within: 5))
        try capture(app, "4.2_draft")
        // The switch, off, is the draft: nothing beside it says so again, and Shape is in the tools row (owner, 31/10/2026), so the
        // switch has the row to itself. Switching it on makes the script ready and the words stay.
        let ready = app.pageReadyToggle
        XCTAssertTrue(ready.exists(within: 5))
        XCTAssertFalse(isOn(ready))
        XCTAssertFalse(element(app, "page.strip.info").exists, "the strip has no line of details beside the switch")
        XCTAssertFalse(element(app, "page.strip").buttons["page.shapeButton"].exists, "Shape is in the tools row, not the strip")
        ready.tap()
        // A storytime has four sections and this one has a single line: the switch asks first.
        XCTAssertTrue(app.alerts.firstMatch.exists(within: 5))
        app.alerts.buttons["Mark ready anyway"].tap()
        XCTAssertTrue(isOn(ready))
        XCTAssertFalse(element(app, "page.strip.info").exists)
        // And back to a draft with one more tap.
        ready.tap()
        XCTAssertFalse(isOn(ready))
    }

    /// Back is how creators leave: it saves and never changes the state (the owner's call, 20/10/2026).
    func testEditingAReadyScriptAndGoingBackKeepsItReady() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.ready)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.exists(within: 5))
        text.tap()
        text.typeText(" One more line.")
        XCTAssertTrue(app.buttons["page.hideKeyboard"].exists, "while typing, the bar's ✓ only hides the keyboard")
        app.buttons["page.hideKeyboard"].tap()
        XCTAssertTrue(isOn(app.pageReadyToggle))
        app.pageBackButton.tap()
        app.openScriptPage(titled: Self.ready)
        XCTAssertTrue(isOn(app.pageReadyToggle), "leaving made it a draft")
    }

    /// The page has the screen to itself: the tab bar goes with the push and is back as soon as the page has gone (the system's own
    /// hiding, so it never comes back late and makes the dock jump).
    func testThePageHidesTheTabBarAndBackBringsItAtOnce() throws {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.cueTabBar.exists(within: 15))
        app.openScriptPage(titled: Self.ready)
        XCTAssertTrue(element(app, "page.strip").exists(within: 5))
        XCTAssertFalse(app.cueTabBar.isHittable, "the tab bar is over the page")
        app.pageBackButton.tap()
        XCTAssertTrue(app.cueTabBar.exists(within: 2) && app.cueTabBar.isHittable)
    }

    /// Undo and Redo on the cues bar over the keyboard: what was typed goes and comes back.
    func testUndoAndRedoOnTheCuesBar() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.ready)
        let text = element(app, "page.editor")
        XCTAssertTrue(text.exists(within: 5))
        text.tap()
        let undo = app.buttons["cuesBar.undo"], redo = app.buttons["cuesBar.redo"]
        XCTAssertTrue(undo.exists(within: 5))
        XCTAssertFalse(undo.isEnabled, "nothing to undo yet")
        text.typeText(" Zebra")
        XCTAssertTrue(undo.isEnabled)
        undo.tap()
        XCTAssertFalse((text.value as? String ?? "").contains("Zebra"), "Undo didn't take the words away")
        XCTAssertTrue(redo.isEnabled)
        redo.tap()
        XCTAssertTrue((text.value as? String ?? "").contains("Zebra"), "Redo didn't bring them back")
    }

    func testAnEmptyPageCannotBeMarkedReady() throws {
        let app = CueApp.launch(seeded: true)
        app.buttons["scripts.newButton"].tap()
        app.buttons["newScript.write"].tap()
        XCTAssertTrue(app.textFields["page.titleField"].exists(within: 10))
        let ready = app.pageReadyToggle
        XCTAssertTrue(ready.exists(within: 5))
        XCTAssertFalse(ready.isEnabled, "nothing to make ready yet")
    }

    func testARecordedScriptSaysChangedSinceTheTakeAfterAnEdit() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.recorded)
        XCTAssertEqual(app.buttons["detail.recordButton"].label, "Retake")
        XCTAssertFalse(app.pageReadyToggle.exists, "a recorded script has no ready switch: recording moved it on")
        try capture(app, "4.1_recorded")
        let text = element(app, "page.editor")
        text.tap()
        text.typeText(" Edited after the take.")
        element(app, "page.strip").tap()
        XCTAssertTrue(strip(app).uppercased().hasPrefix("CHANGED SINCE TAKE"))
        try capture(app, "4.1_recorded_changed")
    }

    /// Shape sits in the tools row beside Improve (owner, 31/10/2026), at its own width, and the row scrolls rather than squeeze it.
    func testShapeInTheToolsRowAddsCuesToAScriptWithNone() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.draft)
        let shape = app.buttons["page.shapeButton"]
        XCTAssertTrue(shape.exists(within: 5))
        let improve = app.buttons["page.improveButton"]
        XCTAssertEqual(shape.frame.midY, improve.frame.midY, accuracy: 2, "Shape is on the tools row")
        XCTAssertGreaterThan(shape.frame.minX, improve.frame.maxX, "Shape follows Improve")
        XCTAssertEqual(shape.frame.midY, app.buttons["page.textSizeButton"].frame.midY, accuracy: 2)
        XCTAssertFalse(element(app, "page.strip").buttons["page.shapeButton"].exists)
        try capture(app, "4.2_tools_row")
        shape.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'cue'")).firstMatch.exists(within: 5))
        XCTAssertFalse(shape.exists(within: 2), "Shape is for scripts with no cues")
    }

    func testTheAIBarRewritesTheSelectionInPlaceAndKeepsOrUndoes() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.ready)
        let text = element(app, "page.editor")
        text.tap()
        text.press(forDuration: 1.0)
        let selectAll = app.menuItems["Select All"]
        if selectAll.exists(within: 3) { selectAll.tap() }
        let shorter = app.buttons["page.selection.shorter"]
        XCTAssertTrue(shorter.exists(within: 5), "No AI bar over a selection")
        try capture(app, "A_ai_bar")
        shorter.tap()
        XCTAssertTrue(app.buttons["page.selection.keep"].exists(within: 10))
        XCTAssertTrue(app.buttons["page.selection.undo"].exists && app.buttons["page.selection.retry"].exists)
        try capture(app, "A_ai_replaced")
        app.buttons["page.selection.undo"].tap()
        XCTAssertFalse(app.buttons["page.selection.keep"].exists)
    }

    /// Without Apple Intelligence the touch-ups aren't there at all, not even dimmed (owner, 01/11/2026), but what runs on rules stays: Shape
    /// adds the cues, the Hook offers the format's starters, and Improve keeps only the tip that this opening runs long (9 words, 3.6 s).
    func testWithoutAppleIntelligenceThePageKeepsWhatRunsOnRulesAndNoTouchUp() throws {
        let app = CueApp.launch(seeded: true, ai: .none)
        app.openScriptPage(titled: Self.draft)
        XCTAssertTrue(element(app, "page.strip").exists(within: 5))
        XCTAssertTrue(app.buttons["page.shapeButton"].exists, "Shape runs on rules: it stays without Apple Intelligence")
        XCTAssertTrue(app.buttons["page.hookButton"].exists)
        try capture(app, "4.1_no_ai")
        let improve = app.buttons["page.improveButton"]
        XCTAssertTrue(improve.exists, "Improve has the hook tip to offer")
        improve.tap()
        XCTAssertTrue(element(app, "improve.hookTip").exists(within: 5), "No tip that the opening runs long")
        try capture(app, "4.2_no_ai_improve")
        let tools = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'improve.tool.'"))
        XCTAssertEqual(tools.count, 0, "A touch-up is offered without Apple Intelligence")
    }
}
