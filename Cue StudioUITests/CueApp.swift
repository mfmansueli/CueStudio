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
    /// `systemLanguage` launches as if the iPhone were in that language; `appearance` ("light" or
    /// "dark") starts Cue's screens in it as if picked in Settings › Appearance.
    static func launch(
        seeded: Bool, pro: Bool = false, ai: AIMode = .stub, sampleVideo: Bool = false, remoteConnects: Bool = false,
        appLanguage: String? = nil, systemLanguage: String? = nil, contentSize: String? = nil, appearance: String? = nil, extraArguments: [String] = []
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestInMemory"] + extraArguments
        if seeded { app.launchArguments.append("-uiTestSeedSamples") }
        if sampleVideo { app.launchArguments.append("-uiTestSampleVideo") }
        if remoteConnects { app.launchArguments.append("-uiTestRemoteConnects") }
        if pro { app.launchArguments.append("-uiTestPro") }
        if let appLanguage { app.launchArguments += ["-uiTestAppLanguage", appLanguage] }
        if let appearance { app.launchArguments += ["-uiTestAppearance", appearance] }
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
    /// Opens "Need an idea?" from its chip on the idea card (the arrow does the same with nothing written).
    func openIdeas() {
        let chip = buttons["ideaCard.ideasChip"]
        XCTAssertTrue(chip.waitForExistence(timeout: 15))
        chip.tap()
        XCTAssertTrue(descendants(matching: .any)["ideas.sheet"].waitForExistence(timeout: 5), "No ideas sheet")
    }
}
