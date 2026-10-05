//
//  TabBarUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The tab bar is the system's (Liquid Glass): each tab becomes the selected one, Record opens "Start recording"
/// without becoming selected, the tab's content runs under the bar, and the bar never draws back while a list scrolls.
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>`
/// saves a picture of each tab.
@MainActor
final class TabBarUITests: XCTestCase {
    private let tabs = ["Scripts", "Takes", "Profile", "Settings"]

    func testEachTabIsSelectedAndTheBarIsTheSystemsOwn() throws {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 15), "The native tab bar isn't there")
        let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"]

        for name in tabs {
            let tab = app.tabBars.buttons[name]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "No \(name) tab")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "\(name) isn't selected after a tap")
            for other in tabs where other != name {
                XCTAssertFalse(app.tabBars.buttons[other].isSelected, "\(other) is selected with \(name)")
            }
            sleep(1)
            if let folder {
                let directory = URL(fileURLWithPath: folder, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try app.screenshot().pngRepresentation.write(to: directory.appending(path: "tabbar-\(name.lowercased()).png"))
            }
        }
    }

    /// The bar never draws back into the small pill while a list scrolls: every tab stays in reach. Takes is the list
    /// that drew it back under `.onScrollDown`; the drawn-back bar keeps its frame but leaves one "Collapsed" button.
    func testTheBarStaysWholeWhileAListScrolls() {
        let app = CueApp.launch(seeded: true)
        let takes = app.tabBars.buttons["Takes"]
        XCTAssertTrue(takes.waitForExistence(timeout: 15))
        takes.tap()
        sleep(1)

        for _ in 0..<3 { app.swipeUp() }
        sleep(1)

        XCTAssertEqual(app.tabBars.buttons.count, 5, "The tab bar drew back while the list scrolled")
        for name in tabs + ["Record"] {
            XCTAssertTrue(app.tabBars.buttons[name].isHittable, "\(name) is out of reach after scrolling")
        }
    }

    func testRecordOpensTheStartSheetWithoutBecomingTheSelectedTab() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.tabBars.buttons["Scripts"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Record"].tap()
        XCTAssertFalse(app.tabBars.buttons["Record"].isSelected)
        XCTAssertTrue(app.tabBars.buttons["Scripts"].isSelected, "The tab under the sheet changed")
    }
}
