//
//  FirstVoyageUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The first voyage (`-uiTestVoyage`; every other UI test runs without it): the strip over an empty Scripts and the list of steps,
/// "Hide guide" and Settings › Personalize bringing it back; and, on the sample library (four steps done), the card taking the creator
/// to the editor with Polish it's tip, whose "Skip this step" moves the card on to sharing.
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
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
    }

    private func waitForGone(_ element: XCUIElement, timeout: TimeInterval = 5) -> Bool {
        let gone = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: element)
        return XCTWaiter.wait(for: [gone], timeout: timeout) == .completed
    }

    // MARK: - An empty library

    func testAnEmptyLibraryShowsTheStripAndHidingItComesBackFromSettings() {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestVoyage"])
        let strip = element(app, "voyage.strip")
        XCTAssertTrue(strip.waitForExistence(timeout: 10))
        XCTAssertTrue(element(app, "empty.inspirationButton").exists, "the three ways in are the first step")
        strip.tap()

        XCTAssertTrue(element(app, "voyage.steps").waitForExistence(timeout: 5))
        for number in 1...6 {
            XCTAssertTrue(element(app, "voyage.step.\(number)").exists, "step \(number)")
        }
        XCTAssertEqual(element(app, "voyage.step.1").value as? String, "Next")
        XCTAssertEqual(element(app, "voyage.step.6").value as? String, "Not done yet")
        let hide = app.buttons["voyage.hide"]
        app.scroll(to: hide)
        hide.tap()
        XCTAssertTrue(waitForGone(strip), "Hide guide put the strip away")

        goToTab(app, "Settings")
        let personalize = element(app, "settings.personalize")
        app.scroll(to: personalize)
        personalize.tap()
        let toggle = app.switches["settings.firstVoyage"]
        app.scrollAboveTabBar(to: toggle)
        XCTAssertEqual(toggle.value as? String, "0")
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
        let on = XCTNSPredicateExpectation(predicate: NSPredicate(format: "value == '1'"), object: toggle)
        XCTAssertEqual(XCTWaiter.wait(for: [on], timeout: 4), .completed)

        goToTab(app, "Scripts")
        XCTAssertTrue(element(app, "voyage.strip").waitForExistence(timeout: 5), "Settings brought the guide back")
    }

    // MARK: - The card leads to the next step

    func testTheCardOpensTheEditorWithPolishsTipAndSkippingMovesOnToSharing() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestVoyage"])
        let card = element(app, "voyage.card")
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        // The button reads the line and what it takes as one (VoiceOver too).
        XCTAssertTrue(element(app, "voyage.next").label.hasPrefix("Next: polish it"), element(app, "voyage.next").label)
        XCTAssertTrue(element(app, "voyage.count").label.contains("4 OF 6"), element(app, "voyage.count").label)

        app.buttons["voyage.action"].tap()
        let tip = element(app, "voyage.tip.5")
        XCTAssertTrue(tip.waitForExistence(timeout: 15), "the editor opens with Polish it's tip")
        XCTAssertTrue(app.buttons["edit.toolbar.captions"].exists || app.buttons["edit.toolbar.edit"].exists, "the tools are under it")
        app.buttons["voyage.tip.secondary"].tap()
        XCTAssertTrue(waitForGone(tip), "Skip this step closes the tip")

        app.buttons["edit.backButton"].tap()
        let back = app.buttons["review.backButton"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        back.tap()
        XCTAssertTrue(card.waitForExistence(timeout: 10))
        let next = element(app, "voyage.next")
        let sharing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH 'Next: share to your universe'"), object: next)
        XCTAssertEqual(XCTWaiter.wait(for: [sharing], timeout: 5), .completed, next.label)
    }
}
