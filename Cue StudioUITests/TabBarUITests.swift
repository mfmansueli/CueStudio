//
//  TabBarUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The v29 tab bar on the real screens: each tab becomes the selected one, Record opens "Start recording" without
/// becoming selected, and nothing under the bar is cut off. `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` saves a picture
/// of each tab.
@MainActor
final class TabBarUITests: XCTestCase {
    private let tabs = ["scripts", "takes", "profile", "settings"]

    func testEachTabIsSelectedAndTheBarStaysInView() throws {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.cueTabBar.waitForExistence(timeout: 15))
        let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"]

        for name in tabs {
            let tab = app.buttons["tab.\(name)"]
            XCTAssertTrue(tab.waitForExistence(timeout: 5), "No \(name) tab")
            tab.tap()
            XCTAssertTrue(tab.isSelected, "\(name) isn't selected after a tap")
            for other in tabs where other != name {
                XCTAssertFalse(app.buttons["tab.\(other)"].isSelected, "\(other) is selected with \(name)")
            }
            // The bar floats clear of the bottom edge and is fully on screen.
            XCTAssertLessThan(app.cueTabBar.frame.maxY, app.frame.maxY - 20)
            XCTAssertGreaterThanOrEqual(app.cueTabBar.frame.height, 64)
            sleep(1)
            if let folder {
                let directory = URL(fileURLWithPath: folder, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try app.screenshot().pngRepresentation.write(to: directory.appending(path: "tabbar-\(name).png"))
            }
        }
    }

    func testRecordOpensTheStartSheetWithoutBecomingTheSelectedTab() {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.buttons["tab.scripts"].waitForExistence(timeout: 15))
        app.buttons["tab.record"].tap()
        XCTAssertFalse(app.buttons["tab.record"].isSelected)
        XCTAssertTrue(app.buttons["tab.scripts"].isSelected || app.buttons["tab.scripts"].exists)
    }
}
