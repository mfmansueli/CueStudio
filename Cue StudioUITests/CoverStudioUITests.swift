//
//  CoverStudioUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Cover Studio from the editor: the five steps, a template picked from real thumbnails, a title typed, a graphic added and
/// moved, Done saving the cover (the timeline's cover block shows it), and Cancel asking before throwing changes away. With
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR` it also saves a picture of each step.
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
        field.typeText("3 habits that changed my mornings\n")
        try capture(app, "3-title-typing")
        app.descendants(matching: .any)["cover.titleHandle"].tap()
        try capture(app, "3-title")

        app.buttons["cover.step.elements"].tap()
        app.buttons["cover.add.arrow"].tap()
        let arrow = app.descendants(matching: .any)["cover.item.arrow"]
        XCTAssertTrue(arrow.exists(within: 3))
        let canvas = app.descendants(matching: .any)["cover.canvas"]
        arrow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            .press(forDuration: 0.1, thenDragTo: canvas.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.7)))
        XCTAssertTrue(app.buttons["cover.itemDelete"].exists, "The picked graphic has its handles")
        try capture(app, "4-graphics")

        app.buttons["cover.step.effects"].tap()
        app.buttons["cover.effect.dim"].tap()
        try capture(app, "5-finish")

        XCTAssertTrue(app.buttons["cover.undo"].isEnabled)
        done.tap()
        XCTAssertFalse(done.exists(within: 1))
        XCTAssertTrue(app.buttons["edit.toolbar.cover"].exists(within: 3))
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
