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
                swipeUp()
            }
            swipes += 1
        }
        XCTAssertTrue(element.waitForExistence(timeout: 5), "Scrolled eight times and \(element) isn't there", file: file, line: line)
    }

    /// The script page's back button: the navigation bar's own (v30).
    var pageBackButton: XCUIElement { navigationBars.buttons["BackButton"].firstMatch }

    /// The search at the top of Scripts' list (always there, the dock stays): its field.
    var scriptsSearchField: XCUIElement { descendants(matching: .any)["scripts.search"].searchFields.firstMatch }

    /// The system tab bar: its buttons are the five tabs, in order Scripts, Takes, Record, Profile, Settings.
    var cueTabBar: XCUIElement { tabBars.firstMatch }

    /// Opens "Need an idea?" from "+" › Let Cue write it (the card's lightbulb chip is gone in v29).
    func openIdeas() {
        let plus = buttons["scripts.newButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()
        let letCue = buttons["newScript.letCue"]
        XCTAssertTrue(letCue.waitForExistence(timeout: 5))
        letCue.tap()
        XCTAssertTrue(descendants(matching: .any)["ideas.sheet"].waitForExistence(timeout: 5), "No ideas sheet")
    }

    /// A script's row on Scripts, scrolled into reach.
    func scriptRow(_ title: String) -> XCUIElement {
        let row = staticTexts[title]
        // Rows are built as they come into view: scroll until this one is there and can be touched.
        _ = buttons["scripts.selectButton"].waitForExistence(timeout: 15)
        for _ in 0..<8 where !(row.exists && row.isHittable) { swipeUp() }
        XCTAssertTrue(row.exists, title)
        return row
    }

    /// Opens a script's page whatever its state: a tap on a ready script or a draft opens it, and a recorded script's row
    /// leads to its videos, so its page is "Open script" in the row's menu.
    func openScriptPage(titled title: String) {
        let row = scriptRow(title)
        row.tap()
        if buttons["detail.recordButton"].waitForExistence(timeout: 3) || pageBackButton.exists { return }
        tabBars.buttons["Scripts"].tap()
        let again = scriptRow(title)
        again.press(forDuration: 1.2)
        buttons["Open script"].tap()
        XCTAssertTrue(pageBackButton.waitForExistence(timeout: 5), "No page for \(title)")
    }

    /// Studio mode from a row's menu (the row's own Studio button is gone in v29).
    func openStudio(titled title: String) {
        scriptRow(title).press(forDuration: 1.2)
        let studio = buttons["Studio mode"]
        XCTAssertTrue(studio.waitForExistence(timeout: 5), "No Studio mode in the menu of \(title)")
        studio.tap()
    }
}
