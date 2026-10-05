//
//  TransitionCatalogueUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The idea's star in the design catalogue (`-uiTestCatalogue transition`), held in "waiting" so each moment can be photographed: opt in
/// with `TEST_RUNNER_CUE_SCREENSHOT_DIR`.
@MainActor
final class TransitionCatalogueUITests: XCTestCase {
    func testTheStarsMomentsAreOnScreen() throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR") }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        func shot(_ name: String, _ app: XCUIApplication) throws {
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
        }
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestCatalogue", "transition", "-uiTestStarTransition"])
        let cancel = app.buttons["transition.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 15))
        try shot("star_1_waiting", app)
        app.buttons["catalogue.transitionReady"].tap()
        try shot("star_2_finishing", app)
    }
}
