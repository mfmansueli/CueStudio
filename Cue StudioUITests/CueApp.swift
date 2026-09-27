//
//  CueApp.swift
//  Cue StudioUITests
//

import XCTest

/// Launches Cue from a known state: in-memory storage, optionally seeded with the sample scripts.
@MainActor
enum CueApp {
    static func launch(seeded: Bool, pro: Bool = false) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestInMemory"]
        if seeded { app.launchArguments.append("-uiTestSeedSamples") }
        if pro { app.launchArguments.append("-uiTestPro") }
        app.launch()
        return app
    }
}
