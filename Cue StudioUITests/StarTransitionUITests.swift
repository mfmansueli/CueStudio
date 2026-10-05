//
//  StarTransitionUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The idea's star is the transition into its script (09 §8): it covers the screen at least three seconds while the AI writes, with Cancel;
/// the script opens under it, or Cancel brings Scripts back with the idea still in the field. `-uiTestStarTransition` keeps the real timings
/// (UI tests shorten them otherwise).
@MainActor
final class StarTransitionUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func launch() -> XCUIApplication {
        CueApp.launch(seeded: true, extraArguments: ["-uiTestStarTransition"])
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(name).png"))
    }

    func testTheStarCoversTheScreenThenOpensTheScript() throws {
        let app = launch()
        let send = app.buttons["ideaCard.submit"]
        XCTAssertTrue(send.waitForExistence(timeout: 15))
        send.tap()
        let cancel = app.buttons["transition.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "No transition")
        sleep(1)
        try capture(app, "transition_waiting")
        // At least three seconds from the tap, then the script is the page.
        XCTAssertTrue(app.pageBackButton.waitForExistence(timeout: 15), "The script never opened")
        // The star lands as the caret and the overlay goes a moment after the page is up.
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: cancel)
        waitForExpectations(timeout: 10)
    }

    /// Cancel is held in the design catalogue's demo, where the star waits as long as it takes to tap it.
    func testCancelMakesTheStarLeaveAndTheOverlayGo() {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestCatalogue", "transition", "-uiTestStarTransition"])
        let cancel = app.buttons["transition.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 15))
        cancel.tap()
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: cancel)
        waitForExpectations(timeout: 10)
    }
}
