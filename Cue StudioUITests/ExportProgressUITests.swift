//
//  ExportProgressUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The review while it exports: "Exporting · N%" and whether Cue can be left (UI tests have no continued tasks: Cue stays
/// open), and a take whose export stopped with Cue last time saying so. With `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>` each
/// state is captured with its hierarchy, for `tools/contrast/audit.py`.
@MainActor
final class ExportProgressUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func openReview(_ arguments: [String]) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: arguments)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.exists(within: 5))
        row.tap()
        XCTAssertTrue(app.buttons["review.shareButton"].exists(within: 10))
        return app
    }

    private func capture(_ app: XCUIApplication, _ name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { return }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
        try app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    func testTheReviewShowsTheExportWhileItRuns() throws {
        let app = openReview(["-uiTestSlowExport"])
        app.buttons["review.shareButton"].tap()
        let card = app.descendants(matching: .any)["review.export.progress"]
        XCTAssertTrue(card.exists(within: 5), "No progress while exporting")
        XCTAssertTrue(card.label.contains("Exporting"), card.label)
        XCTAssertTrue(card.label.contains("Keep Cue open until it’s done."), card.label)
        try capture(app, "export-progress")
        // Gone once the file is made.
        XCTAssertTrue(app.descendants(matching: .any)["ready.sheet"].exists(within: 30))
        XCTAssertFalse(card.exists)
    }

    func testATakeWhoseExportStoppedSaysSoUntilClosed() throws {
        let app = openReview(["-uiTestStoppedExport"])
        let card = app.descendants(matching: .any)["review.exportStopped"]
        XCTAssertTrue(card.exists(within: 5), "The stopped export isn't told")
        XCTAssertTrue(app.buttons["review.exportStopped.save"].exists)
        try capture(app, "export-stopped")
        app.buttons["review.exportStopped.close"].tap()
        XCTAssertFalse(card.exists(within: 2))
    }
}
