//
//  TakesUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Takes tab (the pipeline, one card or row per video, platform filter, day sections) and the
/// take review.
@MainActor
final class TakesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testLibraryShowsVideosByDayWithThePipelineAndFilters() {
        let app = openTakes()
        XCTAssertTrue(app.staticTexts["Today"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Yesterday"].exists)
        XCTAssertTrue(videoRow(app, containing: "3 morning habits").exists)
        XCTAssertTrue(videoRow(app, containing: "3 takes · Best: Take 3").exists)

        // The pipeline: four stages, each with a count, in order.
        XCTAssertTrue(element(app, "takes.pipeline").exists)
        for stage in ["pick", "edit", "ready", "shared"] {
            XCTAssertTrue(app.buttons["takes.stage.\(stage)"].exists, "Missing the \(stage) stage")
        }

        // The platform chips filter.
        app.buttons["takes.platform.youtube"].tap()
        XCTAssertTrue(videoRow(app, containing: "Weekly Q&A").waitForExistence(timeout: 5))
        XCTAssertFalse(videoRow(app, containing: "3 morning habits").exists)
        app.buttons["takes.platform.all"].tap()

        // A stage in the pipeline shows only its videos; tapping it again shows everything.
        app.buttons["takes.stage.ready"].tap()
        XCTAssertTrue(videoRow(app, containing: "3 morning habits").waitForExistence(timeout: 5))
        XCTAssertFalse(videoRow(app, containing: "Unboxing the Lumen").exists)
        app.buttons["takes.stage.ready"].tap()
        XCTAssertTrue(videoRow(app, containing: "Unboxing the Lumen").waitForExistence(timeout: 5))
    }

    func testTheNextLineOpensTheVideoThatWaitsTheLongest() {
        let app = openTakes()
        let next = app.buttons["takes.next"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        next.tap()
        XCTAssertTrue(element(app, "review.takeLabel").waitForExistence(timeout: 5))
    }

    func testTheLibraryCanBeAListAndRemembersIt() {
        let app = openTakes()
        XCTAssertTrue(layoutSegment(app, "List").waitForExistence(timeout: 5))
        layoutSegment(app, "List").tap()
        XCTAssertTrue(videoRow(app, containing: "3 morning habits").waitForExistence(timeout: 5))
        layoutSegment(app, "Grid").tap()
        XCTAssertTrue(videoRow(app, containing: "3 morning habits").waitForExistence(timeout: 5))
    }

    /// Holding a video (grid and list) lifts its card and shows its actions; the preview is drawn
    /// outside the screen's hierarchy, so it needs every service the card reads.
    func testHoldingAVideoShowsItsActions() {
        let app = openTakes()
        for layout in ["Grid", "List"] {
            layoutSegment(app, layout).tap()
            let row = videoRow(app, containing: "3 morning habits")
            XCTAssertTrue(row.waitForExistence(timeout: 5))
            row.press(forDuration: 1.2)
            XCTAssertTrue(app.buttons["Mark as best"].waitForExistence(timeout: 5) || app.buttons["Best take"].exists,
                          "The \(layout)'s menu never opened")
            XCTAssertTrue(app.buttons["Retake"].exists)
            XCTAssertEqual(app.state, .runningForeground, "Holding a video in the \(layout) closed the app")
            // Out of the menu: a tap on the dimmed screen at its left edge, beside the lifted card and the menu.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.04, dy: 0.5)).tap()
            XCTAssertTrue(app.buttons["Retake"].waitForNonExistence(timeout: 5))
        }
    }

    func testReviewOpensPausedAndSwitchesBetweenTakesAndPicksTheBest() {
        let app = openTakes()
        let row = videoRow(app, containing: "3 morning habits")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()

        let label = element(app, "review.takeLabel")
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        XCTAssertTrue(label.label.localizedCaseInsensitiveContains("Take 3"))
        // It opens paused: the play button is there.
        XCTAssertTrue(app.buttons["Play"].waitForExistence(timeout: 5))
        // Where the video is on its way out, and what the length does against the platform.
        XCTAssertTrue(element(app, "review.stageBar").exists)

        // The pill is a menu: it steps to the other takes of the video.
        for _ in 0..<2 {
            element(app, "review.takeLabel").tap()
            XCTAssertTrue(app.buttons["Previous take"].waitForExistence(timeout: 3))
            app.buttons["Previous take"].tap()
        }
        XCTAssertTrue(element(app, "review.takeLabel").label.localizedCaseInsensitiveContains("Take 1"))

        app.buttons["review.bestButton"].tap()
        XCTAssertTrue(app.staticTexts["Take 1 marked as best"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.buttons["review.bestButton"].value as? String, "On")
    }

    func testDeletingATakeMovesToAnother() {
        let app = openTakes()
        let row = videoRow(app, containing: "3 morning habits")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        let delete = app.buttons["review.deleteButton"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()
        // No question first: it is gone at once, and the toast brings Undo for 4 s (04 · F4).
        XCTAssertTrue(app.staticTexts["Take 3 deleted"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["toast.action"].exists)
        XCTAssertTrue(element(app, "review.takeLabel").label.localizedCaseInsensitiveContains("Take 2"))
    }

    func testReviewHasTheV26Actions() {
        let app = openTakes()
        let row = videoRow(app, containing: "3 morning habits")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["review.shareButton"].waitForExistence(timeout: 5))
        for id in ["review.editButton", "review.retakeButton", "review.saveButton", "review.scriptButton"] {
            XCTAssertTrue(element(app, id).exists, "Missing \(id)")
        }
        // Share is the one yellow action: it names the platform.
        XCTAssertTrue(app.buttons["review.shareButton"].label.hasPrefix("Share"))
        // Back, the take's menu, the star and the bin are the system's navigation bar.
        let bar = app.navigationBars.firstMatch
        for id in ["review.backButton", "review.bestButton", "review.deleteButton"] {
            XCTAssertTrue(bar.buttons[id].exists, "\(id) isn't in the navigation bar")
        }
        XCTAssertTrue(bar.descendants(matching: .any)["review.takeLabel"].exists)
    }

    // MARK: - Helpers

    private func openTakes() -> XCUIApplication {
        let app = CueApp.launch(seeded: true)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        return app
    }

    /// List | Grid: a segment of the system's segmented control in the navigation bar.
    private func layoutSegment(_ app: XCUIApplication, _ label: String) -> XCUIElement {
        app.segmentedControls["takes.layout"].buttons[label]
    }

    private func videoRow(_ app: XCUIApplication, containing text: String) -> XCUIElement {
        app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS %@", text)).firstMatch
    }

    private func element(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier].firstMatch
    }
}
