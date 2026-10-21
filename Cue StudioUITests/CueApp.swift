//
//  CueApp.swift
//  Cue StudioUITests
//

import XCTest

/// Launches Cue from a known state: in-memory storage, optionally seeded with the sample scripts,
/// and a predictable AI (or none) so tests never wait for a model.
@MainActor
enum CueApp {
    enum AIMode {
        /// Instant, fixed answers.
        case stub
        /// A device without Apple Intelligence.
        case none
    }

    /// `sampleVideo` puts small real videos behind the "3 morning habits" takes (for Quick edit).
    /// `remoteConnects` makes a pretend iPad join as soon as remote pairing starts.
    /// `appLanguage` starts Cue's interface in that `.lproj` as if picked in Language & Region;
    /// `systemLanguage` launches as if the iPhone were in that language. Nothing animates (`-uiTestFastAnimations`)
    /// unless `animations` asks for the real ones.
    static func launch(
        seeded: Bool, pro: Bool = false, ai: AIMode = .stub, sampleVideo: Bool = false, remoteConnects: Bool = false,
        appLanguage: String? = nil, systemLanguage: String? = nil, contentSize: String? = nil, animations: Bool = false,
        extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestInMemory"] + extraArguments
        if seeded { app.launchArguments.append("-uiTestSeedSamples") }
        if sampleVideo { app.launchArguments.append("-uiTestSampleVideo") }
        if remoteConnects { app.launchArguments.append("-uiTestRemoteConnects") }
        if pro { app.launchArguments.append("-uiTestPro") }
        // `TEST_RUNNER_CUE_UI_ANIMATIONS=1` runs every test with the real animations, to compare.
        if !animations, ProcessInfo.processInfo.environment["CUE_UI_ANIMATIONS"] == nil {
            app.launchArguments.append("-uiTestFastAnimations")
        }
        if let appLanguage { app.launchArguments += ["-uiTestAppLanguage", appLanguage] }
        if let systemLanguage { app.launchArguments += ["-AppleLanguages", "(\(systemLanguage))"] }
        if let contentSize { app.launchArguments += ["-UIPreferredContentSizeCategoryName", contentSize] }
        switch ai {
        case .stub: app.launchArguments.append("-uiTestStubAI")
        case .none: app.launchArguments.append("-uiTestNoAI")
        }
        app.launch()
        return app
    }
}

extension XCUIApplication {
    /// Swipes up until `element` can be tapped, at most eight times, then checks it is there. One question to the app per
    /// swipe (`isHittable` is false for an element that doesn't exist yet). With `container`, the swipes go to it while it is
    /// on screen (a sheet's own scroll view), to the screen otherwise.
    func scroll(to element: XCUIElement, in container: XCUIElement? = nil, file: StaticString = #filePath, line: UInt = #line) {
        var swipes = 0
        while swipes < 8, !element.isHittable {
            if let container, container.exists {
                container.swipeUp()
            } else {
                // Along the left edge, clear of the rows' controls: a swipe through the middle can land on a slider's thumb, which takes
                // the drag (its fine adjustment) instead of scrolling the page.
                let from = coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.72))
                // Held at the end so the list stops under the finger: a tap while it still glides only stops it.
                from.press(
                    forDuration: 0.05, thenDragTo: coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.3)),
                    withVelocity: .default, thenHoldForDuration: 0.1
                )
            }
            swipes += 1
        }
        XCTAssertTrue(element.exists(within: 5), "Scrolled eight times and \(element) isn't there", file: file, line: line)
        // A swipe glides on after the finger lifts: a tap while the list still moves can miss.
        if swipes > 0 { element.waitUntilStill() }
    }

    /// `scroll(to:)`, then on to where the list ends when `element` is still under the tab bar: the last row of a page counts as
    /// hittable there, and a tap on it lands on a tab (on the selected one it goes back to the tab's root).
    func scrollAboveTabBar(to element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        scroll(to: element, file: file, line: line)
        for _ in 0..<3 where cueTabBar.exists && element.frame.maxY > cueTabBar.frame.minY {
            swipeUp()
        }
        let limit = cueTabBar.exists ? cueTabBar.frame.minY : frame.maxY
        XCTAssertLessThanOrEqual(element.frame.maxY, limit, "\(element) is under the tab bar", file: file, line: line)
    }

    /// The script page's "Ready to record" switch (a toggle to VoiceOver, so not among `buttons`).
    var pageReadyToggle: XCUIElement { descendants(matching: .any)["page.readyToggle"].firstMatch }

    /// The script page's back button: the navigation bar's own (v30).
    var pageBackButton: XCUIElement { navigationBars.buttons["BackButton"].firstMatch }

    /// The search at the top of Scripts' list (opened by the bar's magnifier, the dock stays): its field.
    var scriptsSearchField: XCUIElement { descendants(matching: .any)["scripts.search"].searchFields.firstMatch }

    /// Opens Scripts' search with the bar's magnifier and returns its field, which has the keyboard.
    @discardableResult
    func openScriptsSearch(timeout: TimeInterval = 15) -> XCUIElement {
        let magnifier = navigationBars.buttons["scripts.searchButton"]
        XCTAssertTrue(magnifier.exists(within: timeout), "No magnifier in Scripts' bar")
        magnifier.tap()
        let field = scriptsSearchField
        XCTAssertTrue(field.exists(within: 5), "The magnifier didn't open the search")
        XCTAssertTrue(keyboards.firstMatch.exists(within: 5), "The search opened without the keyboard")
        return field
    }

    /// The system tab bar: its buttons are the five tabs, in order Scripts, Takes, Record, Profile, Settings.
    var cueTabBar: XCUIElement { tabBars.firstMatch }

    /// Opens Find inspiration from "+" › Let Cue draft it (the dock's lightbulb opens it too).
    func openIdeas() {
        let plus = buttons["scripts.newButton"]
        XCTAssertTrue(plus.exists(within: 15))
        plus.tap()
        let letCue = buttons["newScript.letCue"]
        XCTAssertTrue(letCue.exists(within: 5))
        letCue.tap()
        XCTAssertTrue(descendants(matching: .any)["inspiration.sheet"].exists(within: 5), "No Find inspiration")
    }

    /// A script's row on Scripts, scrolled into reach.
    func scriptRow(_ title: String) -> XCUIElement {
        let row = staticTexts[title]
        // Rows are built as they come into view: scroll until this one is there and can be touched.
        _ = buttons["scripts.selectButton"].exists(within: 15)
        for _ in 0..<8 where !(row.exists && row.isHittable) { swipeUp() }
        XCTAssertTrue(row.exists, title)
        return row
    }

    /// Opens a script's page: a tap on its row opens it, whatever its state (a recorded one's videos are its "×n ›").
    func openScriptPage(titled title: String) {
        scriptRow(title).tap()
        XCTAssertTrue(pageBackButton.exists(within: 5), "No page for \(title)")
    }

    /// Studio mode from a row's menu (the row's own Studio button is gone in v29).
    func openStudio(titled title: String) {
        scriptRow(title).press(forDuration: 1.2)
        let studio = buttons["Studio mode"]
        XCTAssertTrue(studio.exists(within: 5), "No Studio mode in the menu of \(title)")
        studio.tap()
    }
}
