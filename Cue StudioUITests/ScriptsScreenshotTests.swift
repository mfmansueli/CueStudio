//
//  ScriptsScreenshotTests.swift
//  Cue StudioUITests
//

import XCTest

/// Captures Scripts, the script page and the idea sheets for the phase reports. Opt-in:
/// `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder> xcodebuild … -only-testing:"Cue StudioUITests/ScriptsScreenshotTests" test`.
@MainActor
final class ScriptsScreenshotTests: XCTestCase {
    func testCaptureScriptsStates() throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture Scripts")
        }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = CueApp.launch(seeded: true)
        func capture(_ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "dark-\(name).png"))
        }
        XCTAssertTrue(app.buttons["ideaCard.submit"].waitForExistence(timeout: 15))
        try capture("01-scripts")
        app.buttons["ideaCard.formatChip"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["format.sheet"].waitForExistence(timeout: 5))
        try capture("02-format")
        app.buttons["format.review"].tap()
        app.buttons["format.confirm"].tap()
        app.buttons["ideaCard.platformChip"].tap()
        try capture("03-create-for")
        app.buttons["destination.tiktok"].tap()
        sleep(1)
        app.openIdeas()
        try capture("04-ideas")
        app.buttons["sheet.closeButton"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 5))
        try capture("05-shaped")
        try capture("06-draft")
        app.buttons["page.menuButton"].tap()
        try capture("07-menu")
    }

    func testCaptureMyCueVoice() throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture My Cue Voice")
        }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = CueApp.launch(seeded: true)
        func capture(_ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "dark-\(name).png"))
        }
        let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("3 dinners under 20 minutes")
        app.buttons["ideaCard.voiceChip"].tap()
        XCTAssertTrue(app.buttons["voiceSetup.role.personal"].waitForExistence(timeout: 5))
        try capture("10-voice-role")
        app.buttons["voiceSetup.role.personal"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        XCTAssertTrue(app.buttons["voiceSetup.niche.food"].waitForExistence(timeout: 5))
        app.buttons["voiceSetup.niche.food"].tap()
        try capture("11-voice-topics")
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.audience.simple"].tap()
        try capture("12-voice-audience")
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.tone.casual"].tap()
        try capture("13-voice-tone")
        app.buttons["voiceSetup.saveButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["page.voicePreview"].waitForExistence(timeout: 15))
        try capture("14-voice-preview")
        app.buttons["page.voice.adjust"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["voiceAdjust.sheet"].waitForExistence(timeout: 5))
        app.buttons["voiceAdjust.tooFormal"].tap()
        try capture("15-voice-adjust")
    }

    /// Profile, Settings and its pages, and the paywall.
    func testCaptureProfileSettingsAndPro() throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture Profile and Settings")
        }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = CueApp.launch(seeded: true)
        func capture(_ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "dark-\(name).png"))
        }
        XCTAssertTrue(app.cueTabBar.buttons["Profile"].waitForExistence(timeout: 15))
        app.cueTabBar.buttons["Profile"].tap()
        XCTAssertTrue(app.buttons["profile.setUpVoiceButton"].waitForExistence(timeout: 5))
        try capture("20-profile-new")
        app.buttons["profile.setUpVoiceButton"].tap()
        XCTAssertTrue(app.buttons["voiceSetup.role.expert"].waitForExistence(timeout: 10))
        app.buttons["voiceSetup.role.expert"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.niche.tech"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.audience.insiders"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        app.buttons["voiceSetup.tone.confident"].tap()
        app.buttons["voiceSetup.saveButton"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["profile.voiceSentence"].firstMatch.waitForExistence(timeout: 5))
        try capture("22-profile-voice")
        app.cueTabBar.buttons["Scripts"].tap()
        XCTAssertTrue(app.buttons["ideaCard.voiceChip"].waitForExistence(timeout: 5))
        try capture("22b-scripts-voice-chip")
        app.cueTabBar.buttons["Profile"].tap()
        let upgrade = app.buttons["profile.upgradeButton"]
        for _ in 0..<8 where !(upgrade.exists && upgrade.isHittable) { app.swipeUp() }
        try capture("20b-profile-plan")
        upgrade.tap()
        XCTAssertTrue(app.descendants(matching: .any)["paywall.benefits"].firstMatch.waitForExistence(timeout: 8))
        try capture("21-paywall")
        app.buttons["paywall.closeButton"].tap()
        app.cueTabBar.buttons["Settings"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.recording"].waitForExistence(timeout: 5))
        try capture("23-settings")
        app.descendants(matching: .any)["settings.recording"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.resolution"].waitForExistence(timeout: 5))
        try capture("24-recording")
        app.navigationBars.buttons.firstMatch.tap()
        app.descendants(matching: .any)["settings.prompter"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["settings.textSize"].firstMatch.waitForExistence(timeout: 5))
        try capture("25-prompter")
        app.navigationBars.buttons.firstMatch.tap()
        app.descendants(matching: .any)["settings.remote"].firstMatch.tap()
        XCTAssertTrue(app.descendants(matching: .any)["remote.statusHero"].waitForExistence(timeout: 5))
        try capture("26-remote")
    }

    /// The Selfie text window and its corner handle, at rest and after a drag.
    func testCapturePrompterTextWindow() throws {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else {
            throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture the prompter")
        }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let app = CueApp.launch(seeded: true)
        func capture(_ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "dark-\(name).png"))
        }
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        let handle = app.descendants(matching: .any)["prompter.textWindowResizeHandle"]
        XCTAssertTrue(handle.waitForExistence(timeout: 5))
        try capture("30-text-window")
        let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        start.press(forDuration: 0.1, thenDragTo: start.withOffset(CGVector(dx: -90, dy: -120)))
        try capture("31-text-window-resized")
    }
}
