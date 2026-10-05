//
//  WritingCatalogueUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The AI writing into the page (`-uiTestCatalogue writing`): the words arriving from light, the caret and the pill. Pictures are saved when
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR` is set.
@MainActor
final class WritingCatalogueUITests: XCTestCase {
    func testTheWordsArriveWithTheCaretAndThePill() throws {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestCatalogue", "writing"])
        XCTAssertTrue(app.descendants(matching: .any)["page.writingPill"].firstMatch.waitForExistence(timeout: 15))
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        for step in 1...3 {
            Thread.sleep(forTimeInterval: 1.4)
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "writing_\(step).png"))
        }
    }
}
