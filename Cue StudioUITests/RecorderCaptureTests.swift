//
//  RecorderCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// Pictures of the recorder's and Settings' new surfaces (09/11/2026: the recommendation card, the storage line, This take, the microphone
/// list, Aa's tabs in Selfie and Studio, Settings' Pro and reset rows), with the hierarchy beside each for `tools/contrast/audit.py`.
/// Opt in with `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`; nothing is asserted beyond each surface opening.
@MainActor
final class RecorderCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func shot(_ app: XCUIApplication, _ name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        sleep(1)
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
        try app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testTheSelfieRecordersNewSurfaces() throws {
        guard ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] != nil else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        // 1.5 GB left: the quiet "About … min left in 4K" line over the controls.
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestFreeSpace", "1500"])
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.exists(within: 15))
        record.tap()
        XCTAssertTrue(element(app, "prompter.storageNotice").exists(within: 5))
        try shot(app, "r01_storage-notice")

        // Another network: the card lists each change against the screen.
        app.buttons["prompter.aspectButton"].tap()
        XCTAssertTrue(app.buttons["destination.youtube"].exists(within: 5))
        try shot(app, "r02_network-picker")
        app.buttons["destination.youtube"].tap()
        XCTAssertTrue(element(app, "prompter.recommendationCard").exists(within: 5))
        try shot(app, "r03_recommendation-card")

        // This take, from the camera pill.
        app.buttons["prompter.setupButton"].tap()
        XCTAssertTrue(element(app, "setup.list").exists(within: 5))
        try shot(app, "r04_this-take")
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["prompter.keepSetupButton"].exists(within: 5))
        app.buttons["prompter.keepSetupButton"].tap()

        // The microphone list.
        app.buttons["prompter.audioInputButton"].tap()
        XCTAssertTrue(element(app, "audioInput.list").exists(within: 5))
        try shot(app, "r05_microphones")
        app.buttons["sheet.closeButton"].firstMatch.tap()

        // Aa's four tabs.
        XCTAssertTrue(app.buttons["prompter.displayButton"].exists(within: 5))
        app.buttons["prompter.displayButton"].tap()
        let tabs = app.segmentedControls["display.tabs"]
        XCTAssertTrue(tabs.exists(within: 5))
        for (index, tab) in ["Reading", "Text", "Window", "Camera"].enumerated() {
            tabs.buttons[tab].tap()
            try shot(app, "r0\(6 + index)_aa-selfie-\(tab.lowercased())")
        }
    }

    /// The owner's report (09/11): grey bands over the camera after Aa. Pictures with the frame before Aa, with Aa open, after it closes,
    /// and after YouTube's recommendation, and the setup line's value each time.
    func testAaAndTheFrameMask() throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDemoCamera"])
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.exists(within: 15))
        record.tap()
        let setup = app.buttons["prompter.setupButton"]
        XCTAssertTrue(setup.exists(within: 5))
        var log = "before: \(setup.value as? String ?? "")\n"
        try shot(app, "m1_before-aa")
        app.buttons["prompter.displayButton"].tap()
        XCTAssertTrue(app.segmentedControls["display.tabs"].exists(within: 5))
        try shot(app, "m2_aa-open")
        app.buttons["display.doneButton"].tap()
        XCTAssertTrue(setup.exists(within: 5))
        log += "after aa: \(setup.value as? String ?? "")\n"
        try shot(app, "m3_aa-closed")
        app.buttons["prompter.aspectButton"].tap()
        app.buttons["destination.youtube"].tap()
        if app.buttons["prompter.useRecommendedButton"].exists(within: 5) { app.buttons["prompter.useRecommendedButton"].tap() }
        log += "after youtube use: \(setup.value as? String ?? "")\n"
        try shot(app, "m4_youtube-used")
        app.buttons["prompter.displayButton"].tap()
        try shot(app, "m5_youtube-aa-open")
        try log.write(toFile: path + "/m-log.txt", atomically: true, encoding: .utf8)
    }

    func testTheStudioAaTabs() throws {
        guard ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] != nil else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.exists(within: 15))
        record.tap()
        let mode = app.segmentedControls["prompter.mode"].buttons["Studio"]
        XCTAssertTrue(mode.exists(within: 5))
        mode.tap()
        XCTAssertTrue(app.buttons["prompter.displayButton"].exists(within: 5))
        app.buttons["prompter.displayButton"].tap()
        let tabs = app.segmentedControls["display.tabs"]
        XCTAssertTrue(tabs.exists(within: 5))
        for (index, tab) in ["Reading", "Text", "Studio"].enumerated() {
            tabs.buttons[tab].tap()
            try shot(app, "r1\(index)_aa-studio-\(tab.lowercased())")
        }
    }

    func testSettingsProAndResetRows() throws {
        guard ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] != nil else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let app = CueApp.launch(seeded: true)
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.exists(within: 15))
        settings.tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists(within: 5))
        element(app, "settings.prompter").tap()
        XCTAssertTrue(app.navigationBars["Prompter"].exists(within: 5))
        try shot(app, "r22_settings-prompter")
        app.navigationBars["Prompter"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].exists(within: 5))
        app.scroll(to: element(app, "settings.restorePurchases"))
        try shot(app, "r20_settings-pro")
        app.scroll(to: app.buttons["Reset my setup"])
        try shot(app, "r21_settings-reset")
    }
}
