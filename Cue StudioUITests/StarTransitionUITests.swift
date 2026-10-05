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

    /// A typed idea is sent with the keyboard up: it goes down as the star rises, and the page opened under the star doesn't bring it back
    /// on its empty title (the AI writes it).
    func testTheKeyboardIsAwayWhileTheStarFliesAndWhenThePageOpens() {
        let app = launch()
        let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("3 tips for better lighting")
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5))
        app.buttons["ideaCard.submit"].tap()
        let cancel = app.buttons["transition.cancel"]
        XCTAssertTrue(cancel.waitForExistence(timeout: 5), "No transition")
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: app.keyboards.firstMatch)
        waitForExpectations(timeout: 2)
        XCTAssertTrue(cancel.exists, "the keyboard went down while the star was still up")
        XCTAssertTrue(app.pageBackButton.waitForExistence(timeout: 15), "The script never opened")
        expectation(for: gone, evaluatedWith: cancel)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(app.keyboards.firstMatch.exists, "the page took the keyboard")
    }

    /// Once the star has landed the page writes, and it is already the page it will be (4.1): the same title, meter and state strip, the
    /// words where they will stay. Nothing moves when the writing ends.
    func testTheWordsArriveWhereTheyWillStay() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestSlowWriting"])
        let send = app.buttons["ideaCard.submit"]
        XCTAssertTrue(send.waitForExistence(timeout: 15))
        send.tap()
        let writing = app.descendants(matching: .any)["page.writingText"].firstMatch
        XCTAssertTrue(writing.waitForExistence(timeout: 10), "The page never started writing")
        expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: app.buttons["transition.cancel"])
        waitForExpectations(timeout: 10)
        sleep(1)
        let writingFrame = writing.frame
        try capture(app, "page_writing")
        let editor = app.descendants(matching: .any)["page.editor"].firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 15), "The writing never ended")
        sleep(1)
        try capture(app, "page_written")
        // The editor's frame holds its text view's insets (8 pt above, 5 pt at the side); the arriving words' frame is the words.
        XCTAssertEqual(editor.frame.minY + 8, writingFrame.minY, accuracy: 1, "the words moved when the writing ended")
        XCTAssertEqual(editor.frame.minX + 5, writingFrame.minX, accuracy: 1)
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
