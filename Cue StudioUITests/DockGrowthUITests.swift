//
//  DockGrowthUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The dock's idea field (Scripts): two lines at first, growing to five as the idea needs them, and at most 200 characters
/// (`IdeaPromptDraft.maxCharacters`), with a count from 160 on.
@MainActor
final class DockGrowthUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// A picture of the dock, when `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>` asks for them.
    private func shot(_ app: XCUIApplication, _ name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { return }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: "dock-\(name).png"))
    }

    func testTheFieldGrowsToFiveLinesAndStopsAtTwoHundredCharacters() throws {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let twoLines = field.frame.height
        XCTAssertFalse(element(app, "ideaCard.counter").exists, "The count only shows near the limit")

        field.tap()
        // Three lines or so: the field is taller than the two it starts with.
        field.typeText(String(repeating: "word ", count: 14))
        let grown = field.frame.height
        XCTAssertGreaterThan(grown, twoLines, "The field did not grow with the idea")
        try shot(app, "1-three-lines")

        // Past five lines (170 characters, and the count shows from 160): it stops growing and scrolls inside.
        field.typeText(String(repeating: "more ", count: 20))
        let atFiveLines = field.frame.height
        XCTAssertGreaterThan(atFiveLines, grown)
        XCTAssertLessThanOrEqual(atFiveLines, twoLines * 2.6, "The field is taller than five lines")
        XCTAssertTrue(element(app, "ideaCard.counter").waitForExistence(timeout: 3), "No count near the limit")
        try shot(app, "2-five-lines")

        // More than the limit: what does not fit is not written.
        field.typeText(String(repeating: "extra ", count: 30))
        let value = try XCTUnwrap(field.value as? String)
        XCTAssertEqual(value.count, 200)
        XCTAssertEqual(field.frame.height, atFiveLines, accuracy: 1, "The field kept growing past five lines")
        XCTAssertEqual(element(app, "ideaCard.counter").label, "200 of 200 characters")
        try shot(app, "3-at-the-limit")

        // At rest again (the keyboard goes away) it is the two lines it started with, and opens again to what the idea needs.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { _, _ in abs(field.frame.height - twoLines) <= 1 }, object: nil
        )
        XCTAssertEqual(XCTWaiter().wait(for: [expectation], timeout: 5), .completed, "The field did not go back to two lines")
        try shot(app, "4-at-rest")
        field.tap()
        let reopened = NSPredicate { _, _ in abs(field.frame.height - atFiveLines) <= 1 }
        XCTAssertEqual(
            XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: reopened, object: nil)], timeout: 5), .completed,
            "The field did not open again to five lines"
        )
    }

    func testAShortIdeaKeepsTheFieldTheSizeItHad() throws {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let twoLines = field.frame.height
        field.tap()
        field.typeText("Three things I stopped buying")
        XCTAssertEqual(field.frame.height, twoLines, accuracy: 1)
        XCTAssertFalse(element(app, "ideaCard.counter").exists)
    }
}
