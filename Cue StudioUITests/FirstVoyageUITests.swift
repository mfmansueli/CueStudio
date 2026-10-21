//
//  FirstVoyageUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The first voyage (`-uiTestVoyage`; every other UI test runs without it), as tips: on an empty Scripts the first step's tip above the
/// dock (which never moves), its "Get an idea", the list of steps from "★ 1 OF 6", ✕ for the session and Settings › Personalize bringing
/// the guide back; and, on the sample library (four steps done), the floating tip taking the creator to the editor with Polish it's tip,
/// whose "Skip" moves the tip above the dock on to sharing.
@MainActor
final class FirstVoyageUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - Helpers

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func goToTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.cueTabBar.buttons[name]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
    }

    private func waitForGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    // MARK: - An empty library

    func testAnEmptyLibraryShowsTheFirstTipAboveTheDockAndSettingsBringsItBack() {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestVoyage"])
        let tip = element(app, "voyage.tip.1")
        XCTAssertTrue(tip.exists(within: 10), "the first step's tip comes above the dock")
        let dock = element(app, "empty.promptCard")
        XCTAssertLessThanOrEqual(tip.frame.maxY, dock.frame.minY + 1, "the tip sits above the dock, not over it")
        XCTAssertTrue(app.buttons["empty.writeButton"].exists, "the ways in are still there")
        XCTAssertTrue(tip.label.contains("Your idea, Cue's draft.") || app.staticTexts["Your idea, Cue's draft."].exists)

        // "Get an idea" opens Find inspiration.
        app.buttons["voyage.tip.primary"].tap()
        XCTAssertTrue(element(app, "inspiration.sheet").exists(within: 5), "Get an idea did nothing")
        app.buttons["sheet.closeButton"].firstMatch.tap()
        XCTAssertTrue(waitForGone(element(app, "inspiration.sheet")))

        // "★ 1 OF 6" opens every step.
        XCTAssertTrue(tip.exists(within: 5))
        app.buttons["voyage.tip.steps"].tap()
        XCTAssertTrue(element(app, "voyage.steps").exists(within: 5))
        for number in 1...6 {
            XCTAssertTrue(element(app, "voyage.step.\(number)").exists, "step \(number)")
        }
        XCTAssertEqual(element(app, "voyage.step.1").value as? String, "Next")
        XCTAssertEqual(element(app, "voyage.step.6").value as? String, "Not done yet")
        app.buttons["sheet.closeButton"].firstMatch.tap()
        XCTAssertTrue(waitForGone(element(app, "voyage.steps")))

        // ✕ puts it away for the session.
        app.buttons["voyage.tip.close"].tap()
        XCTAssertTrue(waitForGone(tip), "✕ closed the tip")

        // Settings › Personalize: off and on again brings it back.
        goToTab(app, "Settings")
        let personalize = element(app, "settings.personalize")
        app.scroll(to: personalize)
        personalize.tap()
        let toggle = app.switches["settings.firstVoyage"]
        app.scrollAboveTabBar(to: toggle)
        XCTAssertEqual(toggle.value as? String, "1")
        for expected in ["0", "1"] {
            toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
            let changed = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == %@", expected), object: toggle)
            XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 4), .completed)
        }
        goToTab(app, "Scripts")
        XCTAssertTrue(element(app, "voyage.tip.1").exists(within: 8), "Settings brought the guide back, its tip too")
    }

    // MARK: - The tip leads to the next step

    func testTheTipOpensTheEditorWithPolishsTipAndSkippingMovesOnToSharing() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestVoyage"])
        let floating = element(app, "voyage.tip.5")
        XCTAssertTrue(floating.exists(within: 10), "four steps done: Polish it's tip floats above the dock")
        app.buttons["voyage.tip.primary"].tap()

        let tip = element(app, "voyage.tip.5")
        XCTAssertTrue(app.buttons["edit.backButton"].exists(within: 15), "the tip opened the editor")
        XCTAssertTrue(tip.exists(within: 10), "the editor opens with Polish it's tip")
        EditorApp.waitUntilReady(app)
        XCTAssertTrue(app.buttons["edit.toolbar.captions"].exists || app.buttons["edit.toolbar.edit"].exists, "the tools are under it")
        app.buttons["voyage.tip.secondary"].tap()
        XCTAssertTrue(waitForGone(tip), "Skip closes the tip")

        app.buttons["edit.backButton"].tap()
        let back = app.buttons["review.backButton"]
        XCTAssertTrue(back.exists(within: 10))
        back.tap()
        XCTAssertTrue(element(app, "voyage.tip.6").exists(within: 10), "the tip above the dock moved on to sharing")
    }
}
