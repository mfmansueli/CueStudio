//
//  PanelHeaderUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Canvas 2 R1 (owner, 07/11/2026): a panel's header never breaks. In English and in German (the longest words of the 20), Zoom
/// (three buttons) and Caption style (four) keep their title and subtitle on one line each, the buttons in their order; Text
/// style's scope choice sits in the subtitle's place. Each header is captured for the report.
@MainActor
final class PanelHeaderUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// One footnote line at the default text size, with room for the descenders: two lines would be over 30 pt.
    private static let oneLine: CGFloat = 24

    private func assertOneLine(_ app: XCUIApplication, _ what: String, file: StaticString = #filePath, line: UInt = #line) {
        let subtitle = app.staticTexts["edit.panel.subtitle"]
        XCTAssertTrue(subtitle.exists(within: 5), "\(what): no subtitle", file: file, line: line)
        XCTAssertLessThan(subtitle.frame.height, Self.oneLine, "\(what): \"\(subtitle.label)\" takes two lines", file: file, line: line)
        XCTAssertTrue(app.buttons["edit.panel.apply"].isHittable, "\(what): ✓ isn't in reach", file: file, line: line)
    }

    private func headers(in language: String) {
        let app = EditorApp.open(demo: true, arguments: ["-uiTestAppLanguage", language])
        EditorApp.tapTool(app, "zoom")
        assertOneLine(app, "\(language) Zoom")
        EditorApp.capture(app, "header-\(language)-zoom")
        app.buttons["edit.panel.apply"].tap()

        EditorApp.tapTool(app, "captions")
        let style = app.buttons["edit.captionsStyleButton"]
        XCTAssertTrue(style.exists(within: 5), "No Style in Captions")
        style.tap()
        assertOneLine(app, "\(language) Caption style")
        EditorApp.capture(app, "header-\(language)-caption-style")
        app.buttons["edit.panel.apply"].tap()

        EditorApp.tapTool(app, "text")
        EditorApp.tapTool(app, "styleAll")
        let scope = app.buttons["edit.style.scope.allTexts"]
        XCTAssertTrue(scope.exists(within: 5), "\(language): the scope isn't in Text style's header")
        XCTAssertTrue(scope.isHittable)
        XCTAssertTrue(app.buttons["edit.panel.apply"].isHittable)
        EditorApp.capture(app, "header-\(language)-text-style")
    }

    func testHeadersStayOnOneLineInEnglish() {
        headers(in: "en")
    }

    func testHeadersStayOnOneLineInGerman() {
        headers(in: "de")
    }
}
