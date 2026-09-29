//
//  CueApp.swift
//  Cue StudioUITests
//

import XCTest

/// Launches Cue from a known state: in-memory storage, optionally seeded with the sample scripts,
/// and a predictable AI (or none) so tests never wait for a model.
@MainActor
enum CueApp {
    enum AI {
        /// Instant, fixed answers.
        case stub
        /// A device without Apple Intelligence.
        case none
    }

    /// `sampleVideo` puts small real videos behind the "3 morning habits" takes (for Quick edit).
    /// `remoteConnects` makes a pretend iPad join as soon as remote pairing starts.
    static func launch(
        seeded: Bool, pro: Bool = false, ai: AI = .stub, sampleVideo: Bool = false, remoteConnects: Bool = false
    ) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-uiTestInMemory"]
        if seeded { app.launchArguments.append("-uiTestSeedSamples") }
        if sampleVideo { app.launchArguments.append("-uiTestSampleVideo") }
        if remoteConnects { app.launchArguments.append("-uiTestRemoteConnects") }
        if pro { app.launchArguments.append("-uiTestPro") }
        switch ai {
        case .stub: app.launchArguments.append("-uiTestStubAI")
        case .none: app.launchArguments.append("-uiTestNoAI")
        }
        app.launch()
        return app
    }
}
