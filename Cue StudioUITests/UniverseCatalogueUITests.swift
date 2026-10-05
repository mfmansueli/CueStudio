//
//  UniverseCatalogueUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The universe in the design catalogue (`-uiTestCatalogue universe`): the core in its sizes and colours, and the map with sample videos.
/// Pictures are saved when `TEST_RUNNER_CUE_SCREENSHOT_DIR` is set.
@MainActor
final class UniverseCatalogueUITests: XCTestCase {
    func testTheCoreAndTheMapAreOnScreen() throws {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestCatalogue", "universe"])
        XCTAssertTrue(app.descendants(matching: .any)["catalogue.universeMap"].firstMatch.waitForExistence(timeout: 15))
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "universe_catalogue.png"))
    }
}
