//
//  LayoutAuditCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// Pictures of the app's fixed screens (Scripts, the script page, Takes, a take's review, Pro, Profile, Your universe, My Cue Voice,
/// Settings, the first flight, the celebrations, the editor's sound) at the size of the iPhone it runs on and at a text size, to see what doesn't fit on the
/// smallest iPhone or doesn't grow with the text. Each screen starts from its own launch, so one that doesn't open never leaves the rest
/// behind it; a control it couldn't find is written to `<name>-misses.txt`, never a failure. Opt-in:
/// `TEST_RUNNER_CUE_AUDIT_DIR=<folder> TEST_RUNNER_CUE_AUDIT_NAME=se [TEST_RUNNER_CUE_AUDIT_SIZE=UICTContentSizeCategoryAccessibilityXXXL]
/// CUE_SIMULATOR="Cue v10 iPhone SE" scripts/test.sh only "Cue StudioUITests/LayoutAuditCaptureTests"`; `TEST_RUNNER_CUE_AUDIT_LANGUAGE=de`
/// runs it in another of Cue's languages (the tabs are then found by their place).
@MainActor
final class LayoutAuditCaptureTests: XCTestCase {
    private var directory: URL!
    private var configuration = "audit"
    private var size: String?
    private var language: String?

    /// Reads the folder, the name and the text size, or skips the test when no folder is given.
    private func begin() throws {
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["CUE_AUDIT_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_AUDIT_DIR to capture") }
        directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        configuration = env["CUE_AUDIT_NAME"] ?? "audit"
        size = env["CUE_AUDIT_SIZE"]
        language = env["CUE_AUDIT_LANGUAGE"]
        continueAfterFailure = true
    }

    // MARK: - Scripts

    func testScripts() throws {
        try begin()
        let app = launch(seeded: true)
        guard wait(app, "scripts.newButton", timeout: 20) else { return }
        shot(app, "scripts")
        scrollDown(app)
        shot(app, "scripts-scrolled")
        if tap(app, "scripts.logbookButton") {
            shot(app, "logbook")
            // Three ideas, to see the list's type.
            let field = app.descendants(matching: .any)["logbook.field"].firstMatch
            if field.exists(within: 5) {
                field.tap()
                for idea in ["Slow mornings with a film camera", "Tiny desk setups that fit a studio flat", "Packing hacks"] { field.typeText(idea + "\n") }
                shot(app, "logbook-ideas")
            } else { miss("logbook.field") }
            _ = tap(app, "logbook.doneButton")
        }
        if tap(app, "ideaCard.formatChip") {
            shot(app, "format")
            app.swipeDown()
            sleep(1)
        }
        if tap(app, "scripts.newButton") {
            shot(app, "new-script")
        }
        let empty = launch(seeded: false)
        guard wait(empty, "scripts.newButton", timeout: 20) else { return }
        shot(empty, "scripts-empty")
    }

    func testScriptPage() throws {
        try begin()
        let app = launch(seeded: true)
        guard wait(app, "scripts.selectButton", timeout: 20) else { return }
        let row = app.staticTexts["Oat & Co. · sponsored read"]
        guard row.exists(within: 5) else { return miss("Oat & Co. row") }
        row.tap()
        guard app.pageBackButton.exists(within: 5) else { return miss("page") }
        shot(app, "page")
        scrollDown(app)
        shot(app, "page-scrolled")
        if tap(app, "page.menuButton") { shot(app, "page-menu") }
    }

    // MARK: - Takes and a take

    func testTakes() throws {
        try begin()
        let app = launch(seeded: true, sampleVideo: true, extra: ["-uiTestExportsLeft", "0"])
        guard openTab(app, "Takes"), let row = morningHabits(app) else { return }
        shot(app, "takes")
        scrollDown(app)
        shot(app, "takes-scrolled")
        let list = app.segmentedControls["takes.layout"].buttons.element(boundBy: 1)
        if list.exists(within: 3) {
            list.tap()
            shot(app, "takes-list")
            app.segmentedControls["takes.layout"].buttons.element(boundBy: 0).tap()
        } else { miss("takes.layout") }
        app.swipeDown()
        guard row.exists(within: 5) else { return miss("takes row") }
        row.tap()
        guard wait(app, "review.shareButton") else { return }
        shot(app, "review")
        scrollDown(app)
        shot(app, "review-scrolled")
        app.swipeDown()
        if app.buttons["review.saveButton"].exists(within: 3) {
            app.buttons["review.saveButton"].tap()
            if wait(app, "exportReady.notNow") {
                shot(app, "export-ready")
                if tap(app, "exportReady.pro"), wait(app, "paywall.buyButton") { shot(app, "pro-calm") }
            }
        } else { miss("review.saveButton") }
    }

    /// The first journey's one celebration (D4): the send-off of a first post with Aurora's row, and the first star on the video in Takes.
    func testCelebrations() throws {
        try begin()
        let posted = recordFirstTake(animations: true, appLanguage: language, contentSize: size, extraArguments: ["-uiTestSendOffAt", "5"])
        postRightAway(posted)
        if wait(posted, "sendoff.icon.use", timeout: 10) { shot(posted, "send-off-first-post") }
        posted.terminate()
        let left = recordFirstTake(appLanguage: language, contentSize: size)
        if tap(left, "review.backButton"), tap(left, "prompter.closeButton"), openTab(left, "Takes") {
            shot(left, "first-star-takes")
        }
    }

    func testPrompter() throws {
        try begin()
        let app = launch(seeded: true)
        let record = app.buttons["row.recordButton"].firstMatch
        guard record.exists(within: 20) else { return miss("row.recordButton") }
        record.tap()
        sleep(2)
        shot(app, "prompter")
        // Studio's bar, out until the first play: its quick adjustments and Voice | Steady, words that must never be cut.
        let studio = app.segmentedControls["prompter.mode"].buttons.element(boundBy: 1)
        guard studio.exists(within: 5) else { return miss("prompter.mode") }
        studio.tap()
        sleep(1)
        shot(app, "studio")
    }

    // MARK: - Profile

    func testProfile() throws {
        try begin()
        let app = launch(seeded: true, extra: ["-uiTestUniverse", "sample"])
        guard openTab(app, "Profile"), wait(app, "profile.creatorCard") else { return }
        shot(app, "profile")
        scrollDown(app)
        shot(app, "profile-2")
        scrollDown(app)
        shot(app, "profile-3")
        if tap(app, "profile.upgradeButton"), wait(app, "paywall.closeButton") {
            // Its opening plays even with the animations sped up.
            sleep(4)
            shot(app, "paywall")
            scrollDown(app)
            shot(app, "paywall-2")
        }
        let voice = launch(seeded: true, extra: ["-uiTestUniverse", "sample"])
        guard openTab(voice, "Profile") else { return }
        let edit = voice.buttons["Edit voice"]
        if edit.exists(within: 10) {
            edit.tap()
            if wait(voice, "voicePage") {
                shot(voice, "my-cue-voice")
                scrollDown(voice)
                shot(voice, "my-cue-voice-2")
            }
        } else { miss("Edit voice") }
    }

    func testUniverse() throws {
        try begin()
        let app = launch(seeded: false, extra: ["-uiTestUniverse", "sample"])
        guard openTab(app, "Profile"), tap(app, "profile.universeLink"), wait(app, "universe.screen") else { return }
        sleep(1)
        shot(app, "universe")
        scrollDown(app)
        shot(app, "universe-2")
        if tap(app, "universe.share") {
            sleep(2)
            shot(app, "universe-share")
            _ = tap(app, "sheet.closeButton")
        }
        if tap(app, "universe.reviewRow"), wait(app, "yearInReview.screen") {
            shot(app, "year-in-review")
            if tap(app, "yearInReview.next") { shot(app, "year-in-review-2") }
        }
    }

    // MARK: - Settings

    func testSettings() throws {
        try begin()
        let app = launch(seeded: true)
        guard openTab(app, "Settings") else { return }
        shot(app, "settings")
        scrollDown(app)
        shot(app, "settings-2")
        for entry in ["recording", "prompter", "remote", "personalize", "languageRegion", "notifications", "privacy"] {
            let row = app.descendants(matching: .any)["settings.\(entry)"].firstMatch
            app.swipeDown()
            app.swipeDown()
            for _ in 0..<6 where !row.isHittable { scrollDown(app) }
            guard row.isHittable else { miss("settings.\(entry)"); continue }
            row.tap()
            sleep(1)
            shot(app, "settings-\(entry)")
            scrollDown(app)
            shot(app, "settings-\(entry)-2")
            app.navigationBars.buttons.firstMatch.tap()
            sleep(1)
        }
    }

    // MARK: - The first flight

    func testFirstFlight() throws {
        try begin()
        for step in ["welcome", "universe", "voyage", "script", "voice"] {
            var extra = ["-uiTestOnboarding", "-uiTestOnboardingStep", step, "-uiTestPermissions", "granted"]
            if step == "voyage" { extra += ["-uiTestPlatformAt", "4"] }
            let app = launch(seeded: false, extra: extra)
            if wait(app, "onboarding.root", timeout: 15) {
                sleep(3)
                shot(app, "onb-\(step)")
            }
            app.terminate()
        }
    }

    // MARK: - Editor sound

    /// The editor's sound on the demo edit: the music's Volume (how far it goes down under the voice), Voice effects on the
    /// voice-over, Cue's music library with a track's ⓘ open down to Browse Files, the sound effects, and Text to speech.
    func testEditorSound() throws {
        try begin()
        var app = openEditor()
        if pick(app, track: 3, showing: "edit.toolbar.beats") {
            EditorApp.tapTool(app, "volume")
            panelShots(app, "volume", "sound-volume")
        }
        app.terminate()
        app = openEditor()
        // On the voice-over; where it's out of sight, from the Audio bar, on the clip under the playhead (the same panel).
        if !pick(app, track: 4, showing: "edit.toolbar.reRecord") {
            app.terminate()
            app = openEditor()
            EditorApp.tapTool(app, "audio")
        }
        EditorApp.tapTool(app, "voiceEffects")
        if tap(app, "edit.voiceEffect.radio") { panelShots(app, "voiceEffects", "sound-voice-effects") }
        app.terminate()
        app = openEditor()
        EditorApp.tapTool(app, "audio")
        EditorApp.tapTool(app, "music")
        if tap(app, "edit.library.info.morningNotes") {
            shot(app, "sound-library")
            // Down to the last track (each page about a third of the list on the smallest iPhone).
            let last = app.descendants(matching: .any)["edit.library.info.stillWater"].firstMatch
            for page in 2...12 {
                scrollDown(app)
                shot(app, "sound-library-\(page)")
                if last.exists && last.isHittable { break }
            }
            if !last.isHittable { miss("edit.library.info.stillWater (last track not reached)") }
        }
        let parts = app.segmentedControls["edit.addSoundPart"]
        if parts.exists(within: 3) {
            parts.buttons.element(boundBy: 1).tap()
            sleep(1)
            shot(app, "sound-effects")
        } else {
            miss("edit.addSoundPart")
        }
        app.terminate()
        app = openEditor()
        EditorApp.tapTool(app, "audio")
        EditorApp.tapTool(app, "textToSpeech")
        if wait(app, "tts.add") {
            sleep(1)
            shot(app, "sound-text-to-speech")
        }
        app.terminate()
    }

    // MARK: - Helpers

    private func launch(seeded: Bool, sampleVideo: Bool = false, extra: [String] = []) -> XCUIApplication {
        CueApp.launch(seeded: seeded, sampleVideo: sampleVideo, appLanguage: language, contentSize: size, extraArguments: extra)
    }

    /// The editor on the demo edit (music under the whole video, a voice-over at 0.5–4.5 s), at the text size asked.
    private func openEditor() -> XCUIApplication {
        EditorApp.open(
            demo: true,
            arguments: (size.map { ["-UIPreferredContentSizeCategoryName", $0] } ?? []) + (language.map { ["-uiTestAppLanguage", $0] } ?? [])
        )
    }

    /// Picks track `index` of the demo edit's five (media, texts, captions, music, voice-over) 2.5 s after the playhead; on a small
    /// iPhone the lower tracks are out of the timeline's sight, which is written down with a picture.
    private func pick(_ app: XCUIApplication, track index: Int, showing id: String) -> Bool {
        let timeline = app.descendants(matching: .any)["edit.timeline"]
        guard timeline.exists(within: 10) else { miss("edit.timeline"); return false }
        EditorApp.showEveryTrack(app)
        let y = EditorApp.trackMiddle(index, of: 5, in: timeline)
        timeline.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0)).withOffset(CGVector(dx: 110, dy: y)).tap()
        guard app.descendants(matching: .any)[id].firstMatch.exists(within: 3) else {
            miss(id)
            shot(app, "missed-\(id)")
            return false
        }
        return true
    }

    /// An editor panel at its top, then once more pushed up to its end.
    private func panelShots(_ app: XCUIApplication, _ panel: String, _ label: String) {
        sleep(1)
        shot(app, label)
        let element = app.descendants(matching: .any)["edit.panel.\(panel)"]
        guard element.exists else { miss("edit.panel.\(panel)"); return }
        element.swipeUp(velocity: .slow)
        sleep(1)
        shot(app, "\(label)-end")
    }

    private func openTab(_ app: XCUIApplication, _ title: String) -> Bool {
        let order = ["Scripts", "Takes", "Record", "Profile", "Settings"]
        let named = app.cueTabBar.buttons[title]
        // In another language the tab is found by its place in the bar.
        let tab = language == nil || named.exists ? named : app.cueTabBar.buttons.element(boundBy: order.firstIndex(of: title) ?? 0)
        guard tab.exists(within: 15) else { miss("tab \(title)"); return false }
        tab.tap()
        sleep(1)
        return true
    }

    private func morningHabits(_ app: XCUIApplication) -> XCUIElement? {
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        guard row.exists(within: 15) else { miss("takes.video 3 morning habits"); return nil }
        return row
    }

    private func wait(_ app: XCUIApplication, _ id: String, timeout: TimeInterval = 8) -> Bool {
        guard app.descendants(matching: .any)[id].firstMatch.exists(within: timeout) else { miss(id); return false }
        return true
    }

    /// Taps a control by identifier, scrolled into reach; a missing one is written down.
    private func tap(_ app: XCUIApplication, _ id: String) -> Bool {
        let element = app.descendants(matching: .any)[id].firstMatch
        guard element.exists(within: 5) else { miss(id); return false }
        for _ in 0..<4 where !element.isHittable { scrollDown(app) }
        guard element.isHittable else { miss("\(id) (not hittable)"); return false }
        element.tap()
        sleep(1)
        return true
    }

    /// One page down, along the left edge (clear of sliders), held at the end so the list stops under the finger.
    private func scrollDown(_ app: XCUIApplication) {
        let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.72))
        from.press(
            forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.05, dy: 0.3)),
            withVelocity: .default, thenHoldForDuration: 0.1
        )
        sleep(1)
    }

    /// Writes down a control that wasn't there, at the end of `<name>-misses.txt`.
    private func miss(_ what: String) {
        let file = directory.appending(path: "\(configuration)-misses.txt")
        let line = Data("\(name): \(what)\n".utf8)
        if let handle = try? FileHandle(forWritingTo: file) {
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: line)
            try? handle.close()
        } else {
            try? line.write(to: file)
        }
    }

    private func shot(_ app: XCUIApplication, _ label: String) {
        let file = "\(configuration)-\(label)"
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "\(file).png"))
        // The hierarchy beside the picture, for `tools/contrast/audit.py`.
        try? app.debugDescription.write(to: directory.appending(path: "\(file).txt"), atomically: true, encoding: .utf8)
    }
}
