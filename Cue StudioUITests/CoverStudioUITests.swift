//
//  CoverStudioUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Cover Studio from the editor: the five steps, a template picked from real thumbnails, a title typed, a graphic added and
/// moved, Done saving the cover (the timeline's cover block shows it), and Cancel asking before throwing changes away. Zoom and
/// Reset in view without scrolling (also on an iPhone SE: `CUE_SIMULATOR="Cue v10 iPhone SE"`), the title's words and the line
/// above in reach with the keyboard up, Effects with Remove cover, Template ending with Save style, and the editor's playhead
/// where it was after picking frames. With `TEST_RUNNER_CUE_SCREENSHOT_DIR` it also saves a picture of each step.
@MainActor
final class CoverStudioUITests: XCTestCase {
    private var folder: URL? {
        ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let folder else { return }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        sleep(1)
        let device = UIDevice.current.name.replacingOccurrences(of: " ", with: "-")
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(device)-cover-\(name).png"))
    }

    func testMakeACoverInFiveSteps() throws {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "cover")
        let done = app.buttons["cover.done"]
        XCTAssertTrue(done.exists(within: 5))
        XCTAssertTrue(app.images["cover.image"].exists(within: 10), "The cover is drawn")
        try capture(app, "1-picture")

        app.buttons["cover.next"].tap()
        let template = app.buttons["cover.template.opinion"]
        XCTAssertTrue(template.exists(within: 5))
        template.tap()
        XCTAssertTrue(template.isSelected)
        try capture(app, "2-template")

        app.buttons["cover.next"].tap()
        let field = app.textFields["cover.titleField"]
        XCTAssertTrue(field.exists(within: 5))
        field.tap()
        if let current = field.value as? String {
            field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        field.typeText("3 habits that changed my mornings")
        try capture(app, "3-title-typing")
        field.typeText("\n")
        app.descendants(matching: .any)["cover.titleHandle"].tap()
        try capture(app, "3-title")
        app.buttons["cover.titleSection.box"].tap()
        XCTAssertTrue(app.buttons["cover.background.box"].exists(within: 3), "Box holds what keeps the words readable")
        try capture(app, "3-title-box")

        app.buttons["cover.step.elements"].tap()
        app.buttons["cover.add.arrow"].tap()
        let arrow = app.descendants(matching: .any)["cover.item.arrow"]
        XCTAssertTrue(arrow.exists(within: 3))
        let canvas = app.descendants(matching: .any)["cover.canvas"]
        arrow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7)))
        XCTAssertTrue(app.buttons["cover.itemDelete"].exists, "The picked graphic has its handles")
        // The picked graphic's controls come first, the add row after them.
        let color = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'cover.itemColor'")).firstMatch
        XCTAssertTrue(color.exists(within: 3))
        XCTAssertLessThan(color.frame.minY, app.buttons["cover.add.arrow"].frame.minY)
        try capture(app, "4-graphics")

        app.buttons["cover.step.effects"].tap()
        app.buttons["cover.effect.dim"].tap()
        try capture(app, "5-effects")

        XCTAssertTrue(app.buttons["cover.undo"].isEnabled)
        done.tap()
        XCTAssertFalse(done.exists(within: 1))
        XCTAssertTrue(app.buttons["edit.toolbar.cover"].exists(within: 3))
    }

    /// Picture: Zoom and Reset sit above the steps on opening, with nothing to scroll (run on an iPhone SE too).
    func testZoomAndResetInViewWithoutScrolling() throws {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "cover")
        let zoom = app.descendants(matching: .any)["cover.zoom"]
        let reset = app.buttons["cover.resetFraming"]
        let steps = app.buttons["cover.step.image"]
        XCTAssertTrue(zoom.exists(within: 5) && reset.exists && steps.exists)
        XCTAssertTrue(app.descendants(matching: .any)["cover.frameStrip"].exists)
        XCTAssertLessThanOrEqual(zoom.frame.maxY, steps.frame.minY + 1, "Zoom is above the step bar")
        XCTAssertLessThanOrEqual(reset.frame.maxY, steps.frame.minY + 1, "Reset is above the step bar")
        XCTAssertEqual(zoom.frame.midY, reset.frame.midY, accuracy: 4, "Zoom and Reset share one row")
        XCTAssertTrue(zoom.isHittable)
        XCTAssertFalse(reset.isEnabled, "Nothing to reset yet")
        app.descendants(matching: .any)["cover.canvas"].pinch(withScale: 1.8, velocity: 2)
        XCTAssertTrue(reset.isEnabled, "Zooming in turns Reset on")
        XCTAssertNotEqual(zoom.value as? String, "100%")
        try capture(app, "1-picture-zoomed")
        reset.tap()
        XCTAssertFalse(reset.isEnabled)
    }

    /// R8: typing the title, the field, Words and its highlighted words stay above the keyboard and its word suggestions;
    /// Line above, tapped with the keyboard up, comes into view above it and takes the typing.
    func testTitleWordsStayInReachWithTheKeyboardUp() throws {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "cover")
        XCTAssertTrue(app.buttons["cover.step.text"].exists(within: 5))
        app.buttons["cover.step.text"].tap()
        let field = app.textFields["cover.titleField"]
        XCTAssertTrue(field.exists(within: 3))
        XCTAssertTrue(app.buttons["cover.titleSection.words"].isSelected, "Title opens on Words")
        field.tap()
        field.typeText(" today")
        let keyboard = app.keyboards.firstMatch
        XCTAssertTrue(keyboard.exists(within: 3))
        // The keyboard's frame leaves out the word suggestions over its keys (44 pt): they cover the panel too.
        let top = keyboard.frame.minY - 44
        let word = app.buttons["cover.highlight.0"]
        XCTAssertTrue(word.exists(within: 3))
        XCTAssertLessThanOrEqual(field.frame.maxY, top)
        XCTAssertLessThanOrEqual(word.frame.maxY, top, "The words that stand out are above the keyboard")
        XCTAssertTrue(word.isHittable)
        let wasOn = word.isSelected
        word.tap()
        XCTAssertNotEqual(word.isSelected, wasOn)
        XCTAssertTrue(keyboard.exists, "Picking a word keeps the keyboard")
        try capture(app, "3-title-keyboard")

        // Line above, under Words: tapped with the keyboard still up, it comes into view above it and takes the typing.
        let kicker = app.textFields["cover.kicker"]
        XCTAssertTrue(kicker.exists)
        kicker.tap()
        kicker.typeText("EP 03")
        XCTAssertTrue(keyboard.exists)
        XCTAssertLessThanOrEqual(kicker.frame.maxY, keyboard.frame.minY - 44, "Line above is in view with the keyboard up")
        XCTAssertEqual(kicker.value as? String, "EP 03")
        try capture(app, "3-title-kicker-keyboard")
    }

    /// Effects ends the steps and keeps Remove cover; Template's row ends with Save style, which asks for a name.
    func testEffectsRemovesTheCoverAndTemplateEndsWithSaveStyle() throws {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "cover")
        let done = app.buttons["cover.done"]
        XCTAssertTrue(done.exists(within: 5))
        done.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.cover"].exists(within: 3))
        EditorApp.tapTool(app, "cover")
        XCTAssertTrue(app.buttons["cover.step.effects"].exists(within: 5))

        app.buttons["cover.step.effects"].tap()
        XCTAssertFalse(app.buttons["cover.next"].exists, "Effects is the last step")
        XCTAssertFalse(app.buttons["cover.saveStyle"].exists, "Save style moved to Template")
        let remove = app.buttons["cover.remove"]
        XCTAssertTrue(remove.exists(within: 3))
        try capture(app, "5-effects-remove")

        app.buttons["cover.step.template"].tap()
        let save = app.buttons["cover.saveStyle"]
        XCTAssertTrue(save.exists(within: 3))
        let last = app.buttons["cover.template.series"]
        var swipes = 0
        while !app.windows.firstMatch.frame.contains(save.frame), swipes < 5 {
            app.buttons["cover.template.educational"].firstMatch.swipeLeft()
            swipes += 1
        }
        XCTAssertGreaterThan(save.frame.minX, last.frame.maxX, "Save style is the row's last card")
        try capture(app, "2-template-save-style")
        save.tap()
        XCTAssertTrue(app.alerts.firstMatch.exists(within: 3), "Save style asks for the style's name")
        app.alerts.firstMatch.buttons.element(boundBy: 0).tap()

        app.buttons["cover.step.effects"].tap()
        remove.tap()
        // The dialog's button, not the step's own (same name).
        let confirm = app.buttons.matching(NSPredicate(format: "label == 'Remove cover' AND identifier != 'cover.remove'")).firstMatch
        XCTAssertTrue(confirm.exists(within: 3))
        confirm.tap()
        XCTAssertFalse(done.exists(within: 2))
    }

    /// R10: the frame strip is the cover's own; after picking frames and Done, the editor's playhead is where it was.
    func testTheEditorsPlayheadStaysWhereItWas() throws {
        let app = EditorApp.open(demo: true)
        EditorApp.scrub(app, points: 200)
        let time = app.staticTexts["edit.timeLabel"]
        XCTAssertTrue(time.exists(within: 3))
        sleep(1)
        let before = time.value as? String
        XCTAssertNotNil(before)
        EditorApp.tapTool(app, "cover")
        let strip = app.descendants(matching: .any)["cover.frameStrip"]
        XCTAssertTrue(strip.exists(within: 5))
        strip.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: strip.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.5)))
        app.buttons["cover.frameForward"].tap()
        app.buttons["cover.done"].tap()
        XCTAssertTrue(app.buttons["edit.toolbar.cover"].exists(within: 3))
        XCTAssertEqual(time.value as? String, before, "The playhead is where it was before the cover")
    }

    func testCancelWithChangesAsksFirst() throws {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "cover")
        XCTAssertTrue(app.buttons["cover.next"].exists(within: 5))
        app.buttons["cover.step.template"].tap()
        app.buttons["cover.template.list"].tap()
        app.buttons["cover.cancel"].tap()
        let discard = app.buttons["Discard changes"]
        XCTAssertTrue(discard.exists(within: 3))
        discard.tap()
        XCTAssertTrue(app.buttons["edit.toolbar.cover"].exists(within: 3))
    }

    func testBeforeAfterHasTwoPicturesAndADivider() throws {
        let app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "cover")
        XCTAssertTrue(app.buttons["cover.step.template"].exists(within: 5))
        app.buttons["cover.step.template"].tap()
        let beforeAfter = app.buttons["cover.template.beforeAfter"]
        XCTAssertTrue(beforeAfter.exists(within: 3))
        var swipes = 0
        let screen = app.windows.firstMatch.frame
        while !screen.contains(beforeAfter.frame), swipes < 4 {
            app.buttons["cover.template.educational"].swipeLeft()
            swipes += 1
        }
        beforeAfter.tap()
        XCTAssertTrue(app.descendants(matching: .any)["cover.divider"].exists(within: 3))
        app.buttons["cover.step.image"].tap()
        let after = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'cover.half.'")).element(boundBy: 1)
        XCTAssertTrue(after.exists(within: 3))
        after.tap()
        XCTAssertTrue(after.isSelected)
        try capture(app, "6-before-after")
    }
}
