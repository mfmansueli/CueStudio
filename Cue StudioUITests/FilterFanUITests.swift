//
//  FilterFanUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The filter rows of Scripts and Takes fold into the chosen chip (`FilterFan`, owner 05/11/2026): a tap opens the row, a pick folds it into
/// the picked chip, a tap on the chosen one or outside folds it without a change, and the tap outside still does its own thing. With
/// `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>` each test also saves a picture of each state, and `testTheLiquidMidway` a burst of frames
/// with the real animations, to look at the liquid between two chips.
@MainActor
final class FilterFanUITests: XCTestCase {
    /// A Reels script among the samples.
    private static let lamp = "Unboxing the Lumen desk lamp"

    override func setUp() {
        continueAfterFailure = false
    }

    private func shot(_ app: XCUIApplication, _ name: String, settle: Bool = true) {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { return }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if settle { sleep(1) }
        try? app.screenshot().pngRepresentation.write(to: folder.appending(path: "fan-\(name).png"))
    }

    func testScriptsFoldIntoTheChosenFilter() {
        let app = CueApp.launch(seeded: true)
        let all = app.buttons["scripts.filter.all"]
        let reels = app.buttons["scripts.filter.reels"]
        XCTAssertTrue(all.exists(within: 15))
        XCTAssertFalse(reels.exists, "Folded, only the chosen chip is there")
        shot(app, "scripts-1-folded")

        all.tap()
        XCTAssertTrue(reels.exists(within: 3), "A tap on the chosen chip opens the row")
        shot(app, "scripts-2-open")

        reels.tap()
        XCTAssertTrue(all.isGone(within: 3), "A pick folds the row")
        XCTAssertTrue(reels.isSelected)
        XCTAssertTrue(app.scriptRow(Self.lamp).exists(within: 3), "The list follows the pick")
        shot(app, "scripts-3-picked")

        reels.tap()
        XCTAssertTrue(all.exists(within: 3))
        reels.tap()
        XCTAssertTrue(all.isGone(within: 3), "A tap on the chosen chip folds the row without a change")
        XCTAssertTrue(reels.isSelected)

        reels.tap()
        XCTAssertTrue(all.exists(within: 3))
        let row = app.scriptRow(Self.lamp)
        row.tap()
        XCTAssertTrue(app.pageBackButton.exists(within: 5), "The tap outside the row did not do its own thing")
    }

    func testTakesFoldAndAScrollFoldsThem() {
        let app = CueApp.launch(seeded: true)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let all = app.buttons["takes.platform.all"]
        let youTube = app.buttons["takes.platform.youtube"]
        XCTAssertTrue(all.exists(within: 10))
        XCTAssertFalse(youTube.exists)
        shot(app, "takes-1-folded")
        all.tap()
        XCTAssertTrue(youTube.exists(within: 3))
        shot(app, "takes-2-open")
        app.swipeUp()
        XCTAssertTrue(youTube.isGone(within: 3), "Scrolling the list folds the row")
    }

    /// Frames of the real movement, for the eye (only with a capture folder).
    func testTheLiquidMidway() throws {
        guard ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] != nil else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let app = CueApp.launch(seeded: true, animations: true)
        let all = app.buttons["scripts.filter.all"]
        XCTAssertTrue(all.exists(within: 15))
        sleep(2)
        all.tap()
        for frame in 0..<6 { shot(app, "liquid-open-\(frame)", settle: false) }
        sleep(1)
        app.buttons["scripts.filter.shorts"].tap()
        for frame in 0..<6 { shot(app, "liquid-fold-\(frame)", settle: false) }
    }

    /// In Arabic the fan is mirrored: the chosen chip at the right, the dots and the opening towards the left.
    func testArabicMirrorsTheFan() {
        let app = CueApp.launch(seeded: true, appLanguage: "ar")
        let all = app.buttons["scripts.filter.all"]
        XCTAssertTrue(all.exists(within: 15))
        XCTAssertGreaterThan(all.frame.midX, app.frame.width / 2, "The chosen chip starts at the right")
        shot(app, "arabic-1-folded")
        all.tap()
        let reels = app.buttons["scripts.filter.reels"]
        XCTAssertTrue(reels.exists(within: 3))
        reels.waitUntilStill()
        XCTAssertLessThan(reels.frame.midX, all.frame.midX, "It opens towards the left")
        shot(app, "arabic-2-open")
    }

    /// The largest text the row takes (accessibility1): chips grow, nothing overlaps the chosen one once open.
    func testLargeTextKeepsTheChipsApart() {
        let app = CueApp.launch(seeded: true, contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        let all = app.buttons["scripts.filter.all"]
        XCTAssertTrue(all.exists(within: 15))
        shot(app, "large-1-folded")
        all.tap()
        let tikTok = app.buttons["scripts.filter.tiktok"]
        XCTAssertTrue(tikTok.exists(within: 3))
        tikTok.waitUntilStill()
        XCTAssertGreaterThan(tikTok.frame.minX, all.frame.maxX, "The chips sit apart")
        shot(app, "large-2-open")
    }
}
