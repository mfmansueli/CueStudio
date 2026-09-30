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
    /// `systemLanguage` launches as if the iPhone were in that language.
    static func launch(
        seeded: Bool, pro: Bool = false, ai: AIMode = .stub, sampleVideo: Bool = false, remoteConnects: Bool = false,
        appLanguage: String? = nil, systemLanguage: String? = nil
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestInMemory"]
        if seeded { app.launchArguments.append("-uiTestSeedSamples") }
        if sampleVideo { app.launchArguments.append("-uiTestSampleVideo") }
        if remoteConnects { app.launchArguments.append("-uiTestRemoteConnects") }
        if pro { app.launchArguments.append("-uiTestPro") }
        if let appLanguage { app.launchArguments += ["-uiTestAppLanguage", appLanguage] }
        if let systemLanguage { app.launchArguments += ["-AppleLanguages", "(\(systemLanguage))"] }
        switch ai {
        case .stub: app.launchArguments.append("-uiTestStubAI")
        case .none: app.launchArguments.append("-uiTestNoAI")
        }
        app.launch()
        return app
    }
}
