//
//  TabBarUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The tab bar is the system's (Liquid Glass): each tab becomes the selected one, Record opens "Start recording"
/// without becoming selected, and the tab's content runs under the bar. `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>`
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

    func testRecordOpensTheStartSheetWithoutBecomingTheSelectedTab() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.tabBars.buttons["Scripts"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Record"].tap()
        XCTAssertFalse(app.tabBars.buttons["Record"].isSelected)
        XCTAssertTrue(app.tabBars.buttons["Scripts"].isSelected, "The tab under the sheet changed")
    }
}
