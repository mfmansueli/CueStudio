//
//  TextSizeUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The interface's text grows with the iPhone's text size (DESIGN_PROJECT §53): the screens that had the board's sizes fixed grow too, and
/// the screens laid out on the board still show their buttons.
@MainActor
final class TextSizeUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    /// A script's title on Scripts grows with the text size (it was 15.5 pt at every size).
    func testTheScriptsListGrowsWithTheTextSize() {
        let regular = rowTitleHeight(contentSize: nil)
        let large = rowTitleHeight(contentSize: "UICTContentSizeCategoryAccessibilityL")
        XCTAssertGreaterThan(large, regular * 1.6, "A row's title is \(regular) pt high at the default size and \(large) pt at AX3")
    }

    /// At the largest text size the first flight's button is on the screen and can be tapped.
    func testTheWelcomesButtonIsOnTheScreenAtTheLargestTextSize() {
        let app = CueApp.launch(
            seeded: false, contentSize: "UICTContentSizeCategoryAccessibilityXXXL", extraArguments: ["-uiTestOnboarding"]
        )
        let start = app.buttons["onboarding.getStarted"]
        XCTAssertTrue(start.exists(within: 15))
        XCTAssertTrue(app.windows.firstMatch.frame.contains(start.frame), "Get started is at \(start.frame)")
        XCTAssertTrue(start.isHittable)
    }

    /// At the largest text size the script page's tools are still there to tap, on one line that scrolls instead of breaking a word.
    func testThePagesToolsStayTappableAtTheLargestTextSize() {
        let app = CueApp.launch(seeded: true, contentSize: "UICTContentSizeCategoryAccessibilityXXXL")
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        let hook = app.buttons["page.hookButton"]
        XCTAssertTrue(hook.exists(within: 5))
        XCTAssertTrue(hook.isHittable)
        XCTAssertLessThan(hook.frame.height, 120, "The Hook chip keeps to one line (\(hook.frame.height) pt)")
    }

    private func rowTitleHeight(contentSize: String?) -> CGFloat {
        let app = CueApp.launch(seeded: true, contentSize: contentSize)
        let title = app.staticTexts["Oat & Co. · sponsored read"]
        XCTAssertTrue(title.exists(within: 20))
        let height = title.frame.height
        app.terminate()
        return height
    }
}
