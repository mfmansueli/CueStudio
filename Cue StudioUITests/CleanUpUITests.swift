//
//  CleanUpUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Clean up on the demo take (four pauses, its words already heard): opened from its tool on Pauses and from Edit by text on
/// Text, the tabs switched in the same panel, Remove with Undo on the toast, and one pause put back.
@MainActor
final class CleanUpUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id]
    }

    private func undoOnToast(_ app: XCUIApplication) -> XCUIElement? {
        app.buttons.matching(identifier: "toast.action").allElementsBoundByIndex.first { $0.isHittable }
    }

    func testCleanUpOpensOnPausesAndSwitchesTabsInPlace() {
        let app = EditorApp.open(demo: true, arguments: ["-uiTestDemoTranscript"])
        EditorApp.tapTool(app, "pauses")
        XCTAssertTrue(element(app, "edit.panel.pauses").exists(within: 5), "Clean up didn't open")
        XCTAssertTrue(element(app, "edit.pause.0").exists(within: 5), "Pauses isn't the first tab")
        XCTAssertTrue(app.buttons["edit.pauses.gap.natural"].exists, "No Gap left")
        app.buttons["edit.panel.tab.words"].tap()
        XCTAssertTrue(element(app, "edit.words.empty").exists(within: 5), "Words didn't show")
        app.buttons["edit.panel.tab.transcript"].tap()
        XCTAssertTrue(app.buttons["edit.transcript.word.2"].exists(within: 5), "Text has no words")
        // The same panel, not a sheet over it.
        XCTAssertTrue(element(app, "edit.panel.pauses").exists)
        app.buttons["edit.panel.tab.pauses"].tap()
        XCTAssertTrue(element(app, "edit.pause.0").exists(within: 5))
    }

    func testEditByTextOpensCleanUpOnText() {
        let app = EditorApp.open(demo: true, arguments: ["-uiTestDemoTranscript"])
        EditorApp.tapTool(app, "editByText")
        XCTAssertTrue(app.buttons["edit.transcript.word.2"].exists(within: 5), "Edit by text didn't open on Text")
        XCTAssertTrue(element(app, "edit.panel.pauses").exists, "Edit by text isn't in Clean up")
        XCTAssertTrue(app.buttons["edit.panel.tab.transcript"].isSelected)
    }

    func testRemovingWithUndoThenPuttingOnePauseBack() {
        let app = EditorApp.open(demo: true, arguments: ["-uiTestDemoTranscript"])
        EditorApp.tapTool(app, "pauses")
        let apply = app.buttons["edit.pauses.apply"]
        XCTAssertTrue(apply.matches(NSPredicate(format: "label == %@", "Remove 4 pauses"), within: 5), apply.label)
        apply.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Removed 4 pauses"))
        XCTAssertEqual(EditorApp.length(app), "00:17.5")
        let undo = undoOnToast(app)
        XCTAssertNotNil(undo, "Removed has no Undo")
        undo?.tap()
        XCTAssertTrue(EditorApp.length(app).hasPrefix("00:21.6"))
        // Again, then one back from Removed.
        EditorApp.tapTool(app, "pauses")
        XCTAssertTrue(apply.exists(within: 5))
        apply.tap()
        XCTAssertEqual(EditorApp.length(app), "00:17.5")
        EditorApp.tapTool(app, "pauses")
        let putBack = app.buttons["edit.removed.pause.0.putBack"]
        XCTAssertTrue(putBack.exists(within: 5), "No Put back")
        putBack.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Pause put back"))
        XCTAssertEqual(EditorApp.length(app), "00:18.5")
    }
}
