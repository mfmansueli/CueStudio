//
//  TextPresetsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Text style's effects and a text handled by hand on the preview, on a title added to the design's demo take: an effect
/// goes on the creator's own words where the text already is, its settings show only while it has one and come off with it;
/// two fingers resize and turn the text, one finger moves it, each gesture one undo step.
@MainActor
final class TextPresetsUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Text › Title at the playhead, its words typed ("ola tudo bem", as a creator wrote them), the keyboard put away by the
    /// Presets tab: Text style open on the new text.
    private func addTitle(_ app: XCUIApplication) {
        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "title")
        let field = app.textFields["edit.textField"]
        XCTAssertTrue(field.exists(within: 5))
        if let current = field.value as? String, !current.isEmpty, current != field.placeholderValue {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText("ola tudo bem")
        app.buttons["edit.panel.tab.animated"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.isGone(within: 3))
    }

    private func waitFor(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    private func middle(_ frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX, y: frame.midY)
    }

    /// `element`'s frame once it stays put: the video grows back as a panel goes (0.3 s), and a text over it with it.
    private func settledFrame(of element: XCUIElement) -> CGRect {
        var frame = element.frame
        for _ in 0..<20 {
            RunLoop.current.run(until: Date().addingTimeInterval(0.15))
            let next = element.frame
            if next == frame { break }
            frame = next
        }
        return frame
    }

    func testAnEffectGoesOnTheCreatorsWordsWhereTheTextIs() {
        let app = EditorApp.open(demo: true)
        addTitle(app)
        let handle = app.descendants(matching: .any)["edit.textHandle"].firstMatch
        XCTAssertTrue(handle.exists(within: 5))
        let place = middle(handle.frame)
        let field = app.textFields["edit.textField"]
        let words = field.value as? String
        // The six effects, ahead of the styles.
        for effect in ["gold", "wave", "pop3D", "neon", "headline", "sheen"] {
            XCTAssertTrue(app.buttons["edit.style.\(effect)"].exists(within: 5), effect)
        }
        XCTAssertFalse(app.buttons["edit.textEffect.remove"].exists)
        EditorApp.capture(app, "text-animated")
        app.buttons["edit.style.gold"].tap()
        // On the one text the preview shows, the picked look says it (only VoiceOver hears "Gold metal on this text"): no toast.
        XCTAssertTrue(app.buttons["edit.style.gold"].matches(NSPredicate(format: "selected == true"), within: 3))
        XCTAssertFalse(EditorApp.toastSays(app, "Gold metal", timeout: 1))
        // The words and the place stay the creator's.
        XCTAssertEqual(field.value as? String, words)
        XCTAssertTrue(waitFor { hypot(self.middle(handle.frame).x - place.x, self.middle(handle.frame).y - place.y) < 3 }, "\(handle.frame)")
        XCTAssertTrue(app.buttons["edit.style.gold"].isSelected)
        EditorApp.capture(app, "text-effect-gold")
        // Its settings, then still: the finish stays and Duration goes.
        XCTAssertTrue(app.buttons["edit.panel.preview"].exists(within: 3))
        XCTAssertTrue(app.descendants(matching: .any)["edit.textEffect.duration"].exists)
        app.buttons["edit.textEffect.motion.still"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.textEffect.duration"].isGone(within: 3))
        app.buttons["edit.panel.tab.styles"].tap()
        EditorApp.capture(app, "text-styles")
        EditorApp.showTextTab(app, "font")
        EditorApp.capture(app, "text-custom-font")
        // Custom › Color offers the metal, and says why there's no background.
        EditorApp.showTextTab(app, "color")
        XCTAssertTrue(app.buttons["edit.textEffect.tone.rose"].exists(within: 3))
        XCTAssertTrue(app.descendants(matching: .any)["edit.textEffect.colorNote"].exists)
        EditorApp.capture(app, "text-custom-color")
        app.buttons["edit.textEffect.tone.rose"].tap()
        app.buttons["edit.panel.tab.animated"].tap()
        // Off again: the type stays, the effect's settings go.
        let remove = app.buttons["edit.textEffect.remove"]
        XCTAssertTrue(remove.exists(within: 3))
        remove.tap()
        XCTAssertTrue(remove.isGone(within: 3))
        XCTAssertEqual(field.value as? String, words)
        // Undo brings the effect back.
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(remove.exists(within: 3))
    }

    func testTheEffectsOwnWayInAndAMotionAreOneAtATime() {
        let app = EditorApp.open(demo: true)
        addTitle(app)
        app.buttons["edit.style.wave"].tap()
        // Custom › Motion: the effect's own way in is the one picked.
        EditorApp.showTextTab(app, "motion")
        let own = app.buttons["edit.motion.preset.effect"]
        XCTAssertTrue(own.exists(within: 3))
        XCTAssertTrue(own.isSelected)
        // A Motion instead: the effect stays, still, and says so.
        app.buttons["edit.motion.preset.fade"].tap()
        XCTAssertTrue(waitFor { app.buttons["edit.motion.preset.fade"].isSelected && !own.isSelected })
        XCTAssertTrue(app.descendants(matching: .any)["edit.motion.effectNote"].exists(within: 3))
        XCTAssertTrue(app.buttons["edit.panel.preview"].exists)
        EditorApp.capture(app, "text-custom-motion")
        app.buttons["edit.panel.tab.animated"].tap()
        XCTAssertTrue(app.buttons["edit.textEffect.motion.still"].exists(within: 3))
        XCTAssertTrue(app.buttons["edit.textEffect.motion.still"].isSelected)
        // A card that moves plays as it shows: the Motion goes, with Undo.
        app.buttons["edit.style.gold"].tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Motion removed"))
        EditorApp.capture(app, "text-motion-removed")
        XCTAssertTrue(app.buttons["edit.textEffect.motion.animated"].isSelected)
        EditorApp.showTextTab(app, "motion")
        XCTAssertTrue(own.exists(within: 3))
        XCTAssertTrue(own.isSelected)
        XCTAssertFalse(app.buttons["edit.motion.preset.fade"].isSelected)
    }

    func testTwoFingersResizeAndTurnATextEachInOneUndoStep() {
        let app = EditorApp.open(demo: true)
        addTitle(app)
        app.buttons["edit.panel.apply"].tap()
        let handle = app.descendants(matching: .any)["edit.textHandle"].firstMatch
        XCTAssertTrue(handle.exists(within: 5))
        let start = settledFrame(of: handle)
        handle.pinch(withScale: 1.7, velocity: 1.5)
        XCTAssertTrue(waitFor { handle.frame.width > start.width * 1.3 }, "\(handle.frame) vs \(start)")
        let grown = handle.frame
        // Bigger by a pinch, and its middle where it was (give or take the fingers' drift).
        XCTAssertLessThan(hypot(middle(grown).x - middle(start).x, middle(grown).y - middle(start).y), 24)
        handle.rotate(.pi / 4, withVelocity: 1.5)
        // Turned, its box stands taller on the screen than it was.
        XCTAssertTrue(waitFor { handle.frame.height > grown.height * 1.3 }, "\(handle.frame) vs \(grown)")
        EditorApp.capture(app, "text-turned")
        let undo = app.buttons["edit.undoButton"]
        undo.tap()
        XCTAssertTrue(waitFor { abs(handle.frame.height - grown.height) < 3 }, "Undo takes the turn alone: \(handle.frame) vs \(grown)")
        undo.tap()
        XCTAssertTrue(waitFor { abs(handle.frame.width - start.width) < 3 }, "Undo takes the pinch alone: \(handle.frame) vs \(start)")
    }

    /// Lock holds on the preview: a locked text dragged stays where it is, the toast says so with Unlock, and unlocked it moves.
    func testALockedTextStaysPutOnThePreviewAndSaysHowToUnlock() {
        let app = EditorApp.open(demo: true)
        addTitle(app)
        app.buttons["edit.panel.apply"].tap()
        let handle = app.descendants(matching: .any)["edit.textHandle"].firstMatch
        XCTAssertTrue(handle.exists(within: 5))
        EditorApp.tapTool(app, "lock")
        XCTAssertTrue(EditorApp.toastSays(app, "Locked in place"))
        // A picked, locked text has a lock where its corner handle was.
        XCTAssertTrue(app.buttons["edit.textLocked"].exists(within: 3))
        XCTAssertFalse(app.buttons["edit.textScale"].exists)
        let start = settledFrame(of: handle)
        let from = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 0, dy: 90)), withVelocity: 300, thenHoldForDuration: 0.2)
        XCTAssertTrue(EditorApp.toastSays(app, "Locked in place"))
        XCTAssertLessThan(abs(middle(settledFrame(of: handle)).y - middle(start).y), 3, "A locked text doesn't follow the finger")
        // The editor's toast (the screen under it has a toast host of its own).
        XCTAssertTrue(app.buttons["toast.action"].firstMatch.exists(within: 3))
        let unlock = app.buttons.matching(identifier: "toast.action").allElementsBoundByIndex.first { $0.isHittable }
        XCTAssertEqual(unlock?.label, "Unlock")
        unlock?.tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Unlocked"))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 0, dy: 90)), withVelocity: 300, thenHoldForDuration: 0.2)
        XCTAssertTrue(waitFor { abs(self.middle(handle.frame).y - self.middle(start).y - 90) < 12 }, "\(handle.frame) vs \(start)")
    }

    func testOneFingerMovesATextAndTheCornerTurnsIt() {
        let app = EditorApp.open(demo: true)
        addTitle(app)
        app.buttons["edit.panel.apply"].tap()
        let handle = app.descendants(matching: .any)["edit.textHandle"].firstMatch
        XCTAssertTrue(handle.exists(within: 5))
        let start = settledFrame(of: handle)
        let from = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        from.press(forDuration: 0.1, thenDragTo: from.withOffset(CGVector(dx: 0, dy: 90)), withVelocity: 300, thenHoldForDuration: 0.2)
        XCTAssertTrue(waitFor { abs(self.middle(handle.frame).y - self.middle(start).y - 90) < 12 }, "\(handle.frame) vs \(start)")
        let moved = handle.frame
        // The corner handle: dragged round the text's middle, it turns it.
        let corner = app.buttons["edit.textScale"]
        XCTAssertTrue(corner.exists(within: 3))
        let grip = corner.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        let round = grip.withOffset(CGVector(dx: -moved.width / 2, dy: moved.width / 2))
        grip.press(forDuration: 0.1, thenDragTo: round, withVelocity: 200, thenHoldForDuration: 0.2)
        XCTAssertTrue(waitFor { handle.frame.height > moved.height * 1.3 }, "\(handle.frame) vs \(moved)")
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(waitFor { abs(handle.frame.height - moved.height) < 3 })
    }
}
