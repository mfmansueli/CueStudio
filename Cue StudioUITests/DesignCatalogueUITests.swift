//
//  DesignCatalogueUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The debug design catalogue: every section opens, and an orb control follows a drag.
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` also saves a picture of each section.
@MainActor
final class DesignCatalogueUITests: XCTestCase {
    func testEverySectionOpensAndAnOrbCanBeAdjusted() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestInMemory", "-uiTestCatalogue", "orbs"]
        app.launch()
        XCTAssertTrue(app.descendants(matching: .any)["catalogue.root"].waitForExistence(timeout: 15))

        let orb = app.descendants(matching: .any)["catalogue.orb.speed"].firstMatch
        XCTAssertTrue(orb.waitForExistence(timeout: 5))
        XCTAssertEqual(orb.value as? String, "140 words per minute")
        // Drag the orb toward the right end of its rail.
        let start = orb.coordinate(withNormalizedOffset: CGVector(dx: 0.45, dy: 0.7))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: 120, dy: 0)))
        XCTAssertNotEqual(orb.value as? String, "140 words per minute")

        let size = app.descendants(matching: .any)["catalogue.orb.size"].firstMatch
        XCTAssertEqual(size.value as? String, "L")
        let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"]
        for name in ["Colors", "Icons", "Orbs", "Effects", "Sky"] {
            app.buttons[name].firstMatch.tap()
            sleep(1)
            if let folder {
                let directory = URL(fileURLWithPath: folder, isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                try app.screenshot().pngRepresentation.write(to: directory.appending(path: "catalogue-\(name.lowercased()).png"))
            }
        }
    }
}
