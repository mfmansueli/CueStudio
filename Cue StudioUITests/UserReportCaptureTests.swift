//
//  UserReportCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// Pictures of the screens the owner reported on 6/10/2026 (the empty Scripts, the "+" sheets, My Cue Voice, Profile, Preview and Fine-tune), to look at
/// beside the rest of the app. Opt in with `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`; nothing is asserted beyond each screen opening.
@MainActor
final class UserReportCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func shot(_ app: XCUIApplication, _ name: String, wait: UInt32 = 1) throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if wait > 0 { sleep(wait) }
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
        // The hierarchy beside the picture, for `tools/contrast/audit.py`.
        try app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testScriptsEmptyAndTheCreationSheets() throws {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(element(app, "empty.promptCard").waitForExistence(timeout: 15))
        try shot(app, "u01_scripts-empty")
        app.buttons["scripts.newButton"].tap()
        XCTAssertTrue(element(app, "newScript.import").waitForExistence(timeout: 5))
        try shot(app, "u02_new-sheet")
        element(app, "newScript.import").tap()
        XCTAssertTrue(element(app, "import.sheet").waitForExistence(timeout: 5))
        try shot(app, "u03_import")
        app.swipeDown(velocity: .fast)
        sleep(1)
        if !element(app, "newScript.format").exists {
            app.buttons["scripts.newButton"].tap()
        }
        XCTAssertTrue(element(app, "newScript.format").waitForExistence(timeout: 5))
        element(app, "newScript.format").tap()
        XCTAssertTrue(element(app, "format.confirm").waitForExistence(timeout: 5))
        try shot(app, "u04_format")
    }

    func testTheFormatChipAndMyCueVoiceOnTheCard() throws {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(element(app, "ideaCard.formatChip").waitForExistence(timeout: 15))
        element(app, "ideaCard.formatChip").tap()
        sleep(1)
        try shot(app, "u05_dock-format")
        app.swipeDown(velocity: .fast)
        sleep(1)
        let voice = element(app, "ideaCard.voiceChip")
        XCTAssertTrue(voice.waitForExistence(timeout: 5))
        voice.tap()
        sleep(1)
        try shot(app, "u06_voice-setup-1")
        // Each step: pick the first option, Continue, and capture the next one.
        for (index, prefix) in [(2, "voiceSetup.role."), (3, "voiceSetup.niche."), (4, "voiceSetup.audience.")] {
            let option = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
            guard option.waitForExistence(timeout: 3) else { break }
            option.tap()
            let next = element(app, "voiceSetup.saveButton")
            guard next.waitForExistence(timeout: 3) else { break }
            next.tap()
            try shot(app, "u06_voice-setup-\(index)")
        }
    }

    func testProfileEmptyPreviewAndVoicePage() throws {
        let app = CueApp.launch(seeded: true)
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        sleep(2)
        // Set up My Cue Voice with the first answer of each question, so Preview and the voice page have a voice to work on.
        let setUp = element(app, "profile.setUpVoiceButton")
        XCTAssertTrue(setUp.waitForExistence(timeout: 5))
        setUp.tap()
        for prefix in ["voiceSetup.role.", "voiceSetup.niche.", "voiceSetup.audience.", "voiceSetup.tone."] {
            let option = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix)).firstMatch
            XCTAssertTrue(option.waitForExistence(timeout: 5), prefix)
            option.tap()
            let next = element(app, "voiceSetup.saveButton")
            XCTAssertTrue(next.waitForExistence(timeout: 3))
            next.tap()
        }
        sleep(2)
        try shot(app, "u07_profile-with-voice")
        let preview = element(app, "profile.voicePreview")
        app.scroll(to: preview)
        preview.tap()
        XCTAssertTrue(element(app, "voice.preview").waitForExistence(timeout: 5))
        try shot(app, "u09_profile-preview")
        let without = app.segmentedControls.buttons["Without"].firstMatch
        if without.exists {
            without.tap()
            try shot(app, "u10_profile-preview-without")
        }
        app.buttons["voice.preview.done"].tap()
        sleep(1)
        let edit = element(app, "profile.editVoice")
        app.scroll(to: edit)
        edit.tap()
        sleep(2)
        try shot(app, "u11_edit-voice")
        let sends = element(app, "voicePage.sends")
        app.scroll(to: sends)
        if sends.exists, sends.isHittable {
            sends.tap()
            sleep(2)
            try shot(app, "u12_what-cue-sends")
        }
    }

    func testProfileOfANewAccount() throws {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestUniverse", "newAccount"])
        let tab = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        sleep(2)
        try shot(app, "u14_profile-new-account")
        let edit = element(app, "profile.editButton")
        if edit.waitForExistence(timeout: 3) {
            edit.tap()
            sleep(2)
            try shot(app, "u15_edit-profile")
        }
    }

    /// The Aa sheet over a recording: the page's rows, to see where the reading line's slider is.
    func testThePrompterSettingsSheetOverARecording() throws {
        let app = CueApp.launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        XCTAssertTrue(record.waitForExistence(timeout: 15))
        record.tap()
        XCTAssertTrue(element(app, "prompter.readingLineHandle").waitForExistence(timeout: 5))
        app.buttons["prompter.displayButton"].tap()
        XCTAssertTrue(element(app, "settings.followVoice").waitForExistence(timeout: 5))
        try shot(app, "u20_prompter-sheet-1")
        for index in 2...4 {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            from.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)))
            try shot(app, "u20_prompter-sheet-\(index)")
        }
        if let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] {
            try app.debugDescription.write(toFile: path + "/prompter-sheet-hierarchy.txt", atomically: true, encoding: .utf8)
        }
    }
}
