//
//  TextStyleUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Text style and Caption style on the design's demo take (a title and a subtitle, eight caption lines in
/// Cue's preset): the panel expands (the video gets smaller, the controls get the room, every tab and
/// control a full touch target), the scope is for the look only, the controls stay in reach over the
/// keyboard, and a text's style reaches the captions only through "Apply this style to captions", which
/// asks first and shows in Caption style as Custom until a preset replaces it (Undo and Redo take it back
/// and forth). Run on the iPhone SE and a 6.1" iPhone: on the SE the styling panels are a sheet.
@MainActor
final class TextStyleUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// Text › Style all, then only the title.
    private func openTextStyle(_ app: XCUIApplication) -> XCUIElement {
        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "styleAll")
        let panel = app.descendants(matching: .any)["edit.panel.textStyle"]
        XCTAssertTrue(panel.waitForExistence(timeout: 5))
        let selected = app.buttons["edit.style.scope.selected"]
        XCTAssertTrue(selected.waitForExistence(timeout: 5))
        selected.tap()
        return panel
    }

    /// What scrolls under the open styling panel's fixed rows (a swipe on the field or the tabs scrolls
    /// nothing): the panel's first scroll view (the preset cards and font chips scroll inside it).
    private func content(_ app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'edit.panel.' AND identifier ENDSWITH 'Style'"))
            .firstMatch.scrollViews.firstMatch
    }

    /// The SE shows the styling panels as a sheet over a preview that doesn't move.
    private func isSheet(_ app: XCUIApplication) -> Bool {
        app.windows.firstMatch.frame.height < 700
    }

    private func waitFor(_ condition: @escaping () -> Bool, timeout: TimeInterval = 5) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if condition() { return true }
            RunLoop.current.run(until: Date().addingTimeInterval(0.1))
        }
        return condition()
    }

    func testExpandingGivesTheControlsTheVideosRoomAndIsKeptForCaptionStyle() {
        let app = EditorApp.open(demo: true)
        let panel = openTextStyle(app)
        let preview = app.descendants(matching: .any)["edit.preview"]
        let expand = app.buttons["edit.panel.expand"]
        XCTAssertEqual(expand.label, "Expand panel")
        XCTAssertGreaterThanOrEqual(expand.frame.height, 44)
        let panelHeight = panel.frame.height
        let previewHeight = preview.frame.height
        expand.tap()
        XCTAssertTrue(waitFor { panel.frame.height > panelHeight + 40 }, "\(panel.frame.height) vs \(panelHeight)")
        XCTAssertEqual(expand.label, "Collapse panel")
        if !isSheet(app) {
            XCTAssertLessThan(preview.frame.height, previewHeight - 40)
        }
        // Every tab in view and a full target; the panel's controls stop above the Home Indicator.
        for tab in ["presets", "font", "color", "motion"] {
            let button = app.buttons["edit.panel.tab.\(tab)"]
            XCTAssertTrue(button.isHittable, tab)
            XCTAssertGreaterThanOrEqual(button.frame.height, 44, tab)
        }
        let swatch = app.buttons["edit.textColor.white"]
        app.scroll(to: swatch, in: content(app))
        XCTAssertGreaterThanOrEqual(swatch.frame.height, 44)
        // At the end of the content, the last control sits well above the Home Indicator.
        let copy = app.buttons["edit.style.copyToCaptions"]
        app.scroll(to: copy, in: content(app))
        content(app).swipeUp()
        XCTAssertGreaterThanOrEqual(copy.frame.height, 44)
        XCTAssertLessThanOrEqual(copy.frame.maxY, app.windows.firstMatch.frame.maxY - 44)

        // Caption style opens expanded too.
        app.buttons["edit.panel.apply"].tap()
        let back = app.buttons["edit.toolbar.back"]
        if back.waitForExistence(timeout: 3) { back.tap() }
        EditorApp.tapTool(app, "captions")
        let style = app.buttons["edit.captionsStyleButton"]
        XCTAssertTrue(style.waitForExistence(timeout: 5))
        style.tap()
        XCTAssertTrue(app.descendants(matching: .any)["edit.panel.captionStyle"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["edit.panel.expand"].label, "Collapse panel")
        app.buttons["edit.panel.expand"].tap()
        XCTAssertTrue(waitFor { app.buttons["edit.panel.expand"].label == "Expand panel" })
    }

    func testTheScopeIsForTheLookAndMotionIsThisTextsAlone() {
        let app = EditorApp.open(demo: true)
        _ = openTextStyle(app)
        let subtitle = app.staticTexts["edit.panel.subtitle"]
        XCTAssertEqual(subtitle.label, "Only this title changes")
        XCTAssertFalse(app.staticTexts["edit.style.scopeNote"].exists)
        app.buttons["edit.style.scope.allTexts"].tap()
        XCTAssertEqual(subtitle.label, "All 2 texts change together")
        XCTAssertTrue(app.staticTexts["edit.style.scopeNote"].waitForExistence(timeout: 3))
        // Motion is the picked text's: no scope, no captions action, and the header says so.
        app.buttons["edit.panel.tab.motion"].tap()
        XCTAssertTrue(waitFor { subtitle.label == "Motion and timing change only this text" }, subtitle.label)
        XCTAssertFalse(app.buttons["edit.style.scope.allTexts"].exists)
        XCTAssertFalse(app.buttons["edit.style.copyToCaptions"].exists)
        XCTAssertTrue(app.buttons["edit.keyframe.toggle"].exists)
        // Back on a look's tab, the scope is where it was left.
        app.buttons["edit.panel.tab.color"].tap()
        XCTAssertTrue(app.buttons["edit.style.scope.allTexts"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["edit.style.scope.allTexts"].isSelected)
        XCTAssertEqual(subtitle.label, "All 2 texts change together")
    }

    /// With the keyboard up the field, the tabs and ✓ stay over it, and the controls under them scroll into
    /// reach: the last one of Presets (the captions action) and of Color (Shadow).
    func testEveryControlIsReachableWithTheKeyboardUp() {
        let app = EditorApp.open(demo: true)
        _ = openTextStyle(app)
        let field = app.textFields["edit.textField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.tap()
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.waitForExistence(timeout: 5))
        let top = keyboard.frame.minY
        for id in ["edit.panel.apply", "edit.panel.tab.presets", "edit.panel.tab.color"] {
            XCTAssertLessThanOrEqual(app.buttons[id].frame.maxY, top + 1, id)
        }
        let copy = app.buttons["edit.style.copyToCaptions"]
        app.scroll(to: copy, in: content(app))
        XCTAssertTrue(copy.isHittable)
        XCTAssertLessThanOrEqual(copy.frame.maxY, top + 1)
        app.buttons["edit.panel.tab.color"].tap()
        let outline = app.buttons["edit.textShadow.outline"]
        app.scroll(to: outline, in: content(app))
        XCTAssertTrue(outline.isHittable)
        XCTAssertLessThanOrEqual(outline.frame.maxY, top + 1)
        outline.tap()
        XCTAssertTrue(outline.isSelected)
    }

    func testApplyingATextsStyleToCaptionsAsksThenShowsCustomUntilAPresetReplacesIt() {
        let app = EditorApp.open(demo: true)
        _ = openTextStyle(app)
        let copy = app.buttons["edit.style.copyToCaptions"]
        app.scroll(to: copy, in: content(app))

        // Cancel: nothing happens.
        copy.tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        XCTAssertTrue(alert.staticTexts["Apply this style to captions?"].exists)
        XCTAssertTrue(alert.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "Your captions use the Cue preset.")).firstMatch.exists)
        alert.buttons["Cancel"].tap()
        XCTAssertTrue(waitFor { !alert.exists })
        XCTAssertFalse(EditorApp.toastSays(app, "Captions use this style", timeout: 1))

        // Apply.
        copy.tap()
        XCTAssertTrue(alert.waitForExistence(timeout: 5))
        alert.buttons["Apply"].tap()
        XCTAssertTrue(EditorApp.toastSays(app, "Captions use this style"))

        // Caption style shows the copy as Custom, picked.
        app.buttons["edit.panel.apply"].tap()
        let back = app.buttons["edit.toolbar.back"]
        if back.waitForExistence(timeout: 3) { back.tap() }
        EditorApp.tapTool(app, "captions")
        let style = app.buttons["edit.captionsStyleButton"]
        XCTAssertTrue(style.waitForExistence(timeout: 5))
        style.tap()
        let custom = app.buttons["edit.captionPreset.custom"]
        XCTAssertTrue(custom.waitForExistence(timeout: 5))
        XCTAssertTrue(custom.isSelected)
        XCTAssertFalse(app.buttons["edit.captionPreset.cue"].isSelected)
        XCTAssertTrue(app.staticTexts["edit.captionCustomNote"].exists)

        // A preset replaces it; Undo brings the copy back, Redo the preset.
        app.buttons["edit.captionPreset.pop"].tap()
        XCTAssertTrue(waitFor { !custom.exists })
        XCTAssertTrue(app.buttons["edit.captionPreset.pop"].isSelected)
        app.buttons["edit.undoButton"].tap()
        XCTAssertTrue(custom.waitForExistence(timeout: 3))
        XCTAssertTrue(custom.isSelected)
        app.buttons["edit.redoButton"].tap()
        XCTAssertTrue(waitFor { !custom.exists })
        XCTAssertTrue(app.buttons["edit.captionPreset.pop"].isSelected)
    }
}
