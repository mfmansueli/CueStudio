//
//  MediaMotionUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Canvas 2 delivery 6 (owner, 07/11/2026), on one project, as a creator edits the demo's video in a window: its panel is
/// Show | Part, Part's Duration offers common lengths and a held + steps on its own (one Undo takes the run back), Volume says
/// Volume, and Motion shows Pop first with when it starts and ends under Advanced. Captured for the report.
@MainActor
final class MediaMotionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func pickTheWindow(_ app: XCUIApplication) {
        EditorApp.scrub(app)
        let handle = app.buttons["edit.mediaHandle"]
        XCTAssertTrue(handle.exists(within: 5), "The demo's video in a window isn't under the playhead")
        handle.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.editMedia"].exists(within: 5), "The video's tools")
    }

    private func waitFor(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    /// "2,0s" or "2.0s", as the language writes it.
    private func seconds(_ label: String) -> Double {
        Double(label.replacingOccurrences(of: ",", with: ".").filter { $0.isNumber || $0 == "." }) ?? -1
    }

    /// The stepper's value ("2,0s"): its label is the name (Duration).
    private func shown(_ element: XCUIElement) -> String {
        element.value as? String ?? ""
    }

    func testAVideoInAWindowHasShowAndPartDurationsVolumeAndMotion() {
        let app = EditorApp.open(demo: true)
        pickTheWindow(app)

        // Show | Part: Show first, the window's controls there; Part holds the part that plays.
        EditorApp.tapTool(app, "editMedia")
        let show = app.buttons["edit.panel.tab.show"], part = app.buttons["edit.panel.tab.part"]
        XCTAssertTrue(show.exists(within: 5) && part.exists, "No Show | Part")
        XCTAssertTrue(show.isSelected)
        XCTAssertTrue(app.buttons["edit.mediaLayout.window"].exists, "The window's controls aren't in Show")
        part.tap()
        let value = app.descendants(matching: .any)["edit.mediaLength.value"]
        XCTAssertTrue(value.exists(within: 5), "No Duration in Part")
        XCTAssertEqual(value.label, "Duration", "The length isn't called Duration")
        EditorApp.capture(app, "media-part")

        // Common lengths: tapping the value opens them, opening alone changes nothing; 2 s is one tap more.
        let before = shown(value)
        value.tap()
        let two = app.buttons["edit.mediaLength.preset.20"]
        XCTAssertTrue(two.exists(within: 3), "No common lengths")
        EditorApp.capture(app, "media-common-lengths")
        XCTAssertEqual(shown(value), before, "Opening the lengths changed the value")
        two.tap()
        XCTAssertTrue(waitFor { abs(self.seconds(self.shown(value)) - 2) < 0.05 }, shown(value))

        // A held + steps on its own; one Undo takes the whole run back.
        let plus = app.buttons["edit.mediaLength.plus"]
        plus.press(forDuration: 2)
        // The system's repeat: a few steps a second (2.0 → 2.5 in 2 s on the Simulator).
        XCTAssertTrue(waitFor { self.seconds(self.shown(value)) >= 2.25 }, "Holding + stepped once: \(shown(value))")
        app.buttons["edit.panel.apply"].tap()
        app.buttons["edit.undoButton"].tap()
        EditorApp.tapTool(app, "editMedia")
        app.buttons["edit.panel.tab.part"].tap()
        XCTAssertTrue(waitFor { abs(self.seconds(self.shown(value)) - 2) < 0.05 }, "One Undo didn't take the held run back: \(shown(value))")
        app.buttons["edit.panel.apply"].tap()

        // Volume: the bar, the title and the control say Volume.
        EditorApp.tapTool(app, "mediaVolume")
        let volume = app.descendants(matching: .any)["edit.mediaSound"]
        XCTAssertTrue(volume.exists(within: 5))
        XCTAssertTrue(app.staticTexts["Volume"].exists)
        XCTAssertFalse(app.staticTexts["Sound"].exists, "The control still says Sound")
        app.buttons["edit.panel.apply"].tap()

        // Motion: Pop first, Track and Keyframes, then Advanced with Starts and Ends.
        EditorApp.tapTool(app, "mediaMotion")
        let pop = app.buttons["edit.motion.preset.pop"], fade = app.buttons["edit.motion.preset.fade"]
        XCTAssertTrue(pop.exists(within: 5))
        XCTAssertLessThan(pop.frame.midX, fade.frame.midX, "Pop isn't first")
        pop.tap()
        XCTAssertTrue(waitFor { pop.isSelected })
        XCTAssertFalse(app.buttons["edit.text.starts.minus"].exists, "Starts is out of Advanced")
        let advanced = app.buttons["edit.panel.advanced"]
        scrollPanelUp(app, to: advanced)
        advanced.tap()
        XCTAssertTrue(app.buttons["edit.text.starts.minus"].exists(within: 3), "Advanced doesn't hold Starts")
        EditorApp.capture(app, "media-motion")
    }

    private func scrollPanelUp(_ app: XCUIApplication, to element: XCUIElement) {
        let panel = app.descendants(matching: .any)["edit.panel.motion"]
        for _ in 0..<6 where !(element.exists && element.isHittable) {
            let start = panel.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.8))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: -160)), withVelocity: 600, thenHoldForDuration: 0.2)
        }
    }
}
