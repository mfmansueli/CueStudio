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
        app.buttons["edit.pauses.settings"].tap()
        XCTAssertTrue(app.buttons["edit.pauses.gap.natural"].exists(within: 3), "No Gap left")
        app.buttons["edit.panel.tab.words"].tap()
        XCTAssertTrue(element(app, "edit.words.empty").exists(within: 5), "Words didn't show")
        app.buttons["edit.panel.tab.transcript"].tap()
        XCTAssertTrue(app.buttons["edit.transcript.word.2"].exists(within: 5), "Text has no words")
        // The same panel, not a sheet over it.
        XCTAssertTrue(element(app, "edit.panel.pauses").exists)
        app.buttons["edit.panel.tab.pauses"].tap()
        XCTAssertTrue(element(app, "edit.pause.0").exists(within: 5))
    }

    /// Canvas 2 F10, M3 and bug 7: Clean up opens on the row of pauses, with the length and the gap behind the header's button;
    /// a mark tapped on the timeline goes to its card and lights it without changing anything, and a second tap on it switches
    /// it; on Text, how to pick words shows while pauses are marked.
    func testTheRowComesFirstAMarkLeadsToItsCardAndTextKeepsHowToPick() {
        let app = EditorApp.open(demo: true, arguments: ["-uiTestDemoTranscript"])
        EditorApp.tapTool(app, "pauses")
        let panel = element(app, "edit.panel.pauses")
        XCTAssertTrue(element(app, "edit.pause.0").exists(within: 5), "No row of pauses")
        XCTAssertFalse(app.buttons["edit.pauses.threshold.minus"].exists, "The settings come before the pauses")
        let settings = app.buttons["edit.pauses.settings"]
        XCTAssertTrue(settings.exists)
        XCTAssertLessThan(settings.frame.midY - panel.frame.minY, 70, "The settings aren't in the header")
        settings.tap()
        XCTAssertTrue(app.buttons["edit.pauses.threshold.minus"].exists(within: 3))
        XCTAssertTrue(app.buttons["edit.pauses.gap.natural"].exists)
        EditorApp.capture(app, "cleanup-settings-open")
        settings.tap()
        XCTAssertFalse(app.buttons["edit.pauses.threshold.minus"].exists(within: 1))
        EditorApp.capture(app, "cleanup-opens-on-row")

        // The first pause on the timeline: its card is lit, nothing changes; tapped again, it's kept.
        let card = element(app, "edit.pause.0")
        let (start, length) = pause(card)
        let apply = app.buttons["edit.pauses.apply"]
        let before = apply.label
        tapTimeline(app, at: start + length / 2)
        XCTAssertTrue(waitFor { card.isSelected }, "The card isn't lit")
        XCTAssertEqual(apply.label, before, "The first tap changed what goes")
        XCTAssertEqual(card.value as? String, "Remove")
        EditorApp.capture(app, "cleanup-mark-to-card")
        tapTimeline(app, at: start + length / 2)
        XCTAssertTrue(waitFor { (card.value as? String) == "Keep" }, "The second tap didn't switch it")
        XCTAssertNotEqual(apply.label, before)

        // Text: how to pick words, with the other pauses still marked.
        app.buttons["edit.panel.tab.transcript"].tap()
        XCTAssertTrue(element(app, "edit.transcript.howToPick").exists(within: 5), "How to pick words is hidden")
        XCTAssertTrue(apply.exists, "Remove isn't at the bottom")
        EditorApp.capture(app, "cleanup-text-how-to-pick")
    }

    /// A card's start and length, from what it says ("1.2s, 00:04.1").
    private func pause(_ card: XCUIElement) -> (start: Double, length: Double) {
        let parts = card.label.components(separatedBy: ", ")
        let length = Double(parts.first?.filter { $0.isNumber || $0 == "." } ?? "") ?? 0
        return (clock(parts.last ?? ""), length)
    }

    /// "00:04.1" in seconds.
    private func clock(_ text: String) -> Double {
        let parts = text.split(separator: ":")
        guard parts.count == 2, let minutes = Double(parts[0]), let seconds = Double(parts[1]) else { return 0 }
        return minutes * 60 + seconds
    }

    /// Taps the video track at `time` (44 points a second, the playhead in the middle at the time the player bar shows).
    private func tapTimeline(_ app: XCUIApplication, at time: Double) {
        let shown = clock((app.staticTexts["edit.timeLabel"].value as? String ?? "").components(separatedBy: " / ").first ?? "")
        EditorApp.mainTrack(app, at: 0.5).withOffset(CGVector(dx: (time - shown) * 44, dy: 0)).tap()
    }

    private func waitFor(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
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
