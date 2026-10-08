//
//  ExploratoryTourTests.swift
//  Cue StudioUITests
//

import XCTest

/// A walk through the whole app that only takes pictures, to look for what the assertions don't:
/// layout that breaks on a small screen, large text or another language, a screen with no way
/// forward. It never fails on a missing control; it writes the controls it could not find to
/// `misses.txt`, because a control that is gone is a lead too. Opt-in:
/// `TEST_RUNNER_CUE_TOUR_DIR=<folder> TEST_RUNNER_CUE_TOUR_NAME=se [TEST_RUNNER_CUE_TOUR_LANG=ar]
/// [TEST_RUNNER_CUE_TOUR_SIZE=UICTContentSizeCategoryAccessibilityXXXL] [TEST_RUNNER_CUE_TOUR_APPEARANCE=light] xcodebuild …
/// -only-testing:"Cue StudioUITests/ExploratoryTourTests" test`.
@MainActor
final class ExploratoryTourTests: XCTestCase {
    private var directory: URL!
    private var tourName = "tour"
    private var count = 0
    private var misses: [String] = []
    private var app: XCUIApplication!

    func testTour() throws {
        try begin()
        shot("start")
        scripts()
        voiceFlow()
        takesAndEditor()
        profileAndSettings()
        try finish("")
    }

    /// Does the editor draw the video? Waits longer than the tour does, then plays a moment.
    func testEditorPreview() throws {
        try begin()
        tab(1)
        let video = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.'")).firstMatch
        guard video.waitForExistence(timeout: 5) else { return }
        video.tap()
        sleep(3)
        shot("preview-review")
        if tap("review.editButton") {
            sleep(8)
            shot("preview-editor-8s")
            if tap("edit.playButton") { sleep(2); shot("preview-editor-playing") }
        }
        try finish("-preview")
    }

    /// Every tool of the editor's toolbar, opened once: the panels are where the layout is tightest.
    func testEditorPanels() throws {
        try begin()
        tab(1)
        let video = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.'")).firstMatch
        guard video.waitForExistence(timeout: 5) else { return }
        video.tap()
        sleep(3)
        guard tap("review.editButton") else { return }
        sleep(4)
        for item in ["edit", "audio", "text", "captions", "filters", "adjust", "crop", "background", "overlay", "smart"] {
            let button = app.descendants(matching: .any)["edit.toolbar.\(item)"].firstMatch
            if !button.exists || !button.isHittable {
                app.descendants(matching: .any)["edit.toolbar"].firstMatch.swipeLeft()
                sleep(1)
            }
            guard button.exists, button.isHittable else { misses.append("edit.toolbar.\(item)"); continue }
            button.tap()
            sleep(2)
            shot("panel-\(item)")
            // Smart opens a row of tools: the first one opens its own panel.
            if item == "smart", tap("edit.smart.autoAdjust") { sleep(2); shot("panel-smart-adjust") }
            if item == "adjust" || item == "smart" {
                if tap("edit.adjust.tint") { shot("panel-adjust-tint") }
            }
            if !tap("edit.panel.apply") { _ = tap("edit.toolbar.back") }
            sleep(1)
        }
        // The cover, from the "Cover" tile before the first clip.
        let cover = app.buttons["Cover"].firstMatch
        if cover.waitForExistence(timeout: 3), cover.isHittable {
            cover.tap(); sleep(2); shot("panel-cover")
            for tab in ["edit.panel.tab.coverText", "edit.panel.tab.elements", "edit.panel.tab.look"] where app.buttons[tab].exists {
                app.buttons[tab].tap(); sleep(1); shot("panel-cover-\(tab.split(separator: ".").last ?? "")")
            }
        } else { misses.append("cover tile") }
        try finish("-panels")
    }

    /// The camera screen, on a launch of its own: it starts from the Scripts list, whatever the walk above left open.
    func testPrompterTour() throws {
        try begin()
        prompter()
        try finish("-prompter")
    }

    /// The v27 screens: the "+" sheet, the Logbook, Answer a comment, Your universe, Personalize, the paywall and
    /// the first voyage. Same opt-in as the tour above.
    func testUniverseTour() throws {
        try begin()
        shot("universe-scripts")
        if tap("scripts.newButton") {
            shot("start-a-video")
            if tap("newScript.answer") { shot("answer-1"); _ = tap("answer.paste"); shot("answer-2-paste"); closeSheet() }
            closeSheet()
        }
        if tap("scripts.logbookButton") {
            shot("logbook")
            if let field = Optional(app.descendants(matching: .any)["logbook.field"].firstMatch), field.exists {
                field.tap(); field.typeText("A long idea about how I stopped planning every single video in advance"); shot("logbook-typed")
            }
            closeSheet()
        }
        tab(3)
        if tap("profile.universeLink") || tap("profile.universeLink") {
            sleep(2)
            shot("your-universe")
            app.swipeUp(); shot("your-universe-2")
            _ = tap("universe.share"); shot("universe-share"); closeSheet()
            app.navigationBars.buttons.firstMatch.tap()
        }
        tab(4)
        app.swipeUp()
        if tap("settings.personalize") {
            shot("personalize"); app.swipeUp(); shot("personalize-2"); app.navigationBars.buttons.firstMatch.tap()
        }
        if tap("settings.prompter") {
            sleep(1)
            shot("prompter-settings")
            app.swipeUp(); shot("prompter-settings-2")
            app.swipeUp(); shot("prompter-settings-3")
        }
        try finish("-universe")
    }

    /// The first voyage, chapter by chapter, from a fresh launch.
    func testOnboardingTour() throws {
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["CUE_TOUR_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_TOUR_DIR to run the tour") }
        directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tourName = env["CUE_TOUR_NAME"] ?? "tour"
        continueAfterFailure = true
        app = CueApp.launch(
            seeded: false, ai: .stub, appLanguage: env["CUE_TOUR_LANG"], contentSize: env["CUE_TOUR_SIZE"],
            extraArguments: ["-uiTestOnboarding", "-uiTestPermissions", "granted"]
        )
        sleep(6)
        shot("onb-1-welcome")
        _ = tap("onboarding.getStarted")
        sleep(2); shot("onb-2-universe")
        _ = tap("onboarding.topic.niche.food"); _ = tap("onboarding.topic.niche.fitness")
        sleep(1); shot("onb-2b-picked")
        _ = tap("onboarding.continue")
        sleep(2); shot("onb-3-voyage")
        _ = tap("onboarding.platform.reels")
        sleep(1); shot("onb-3b-reels")
        _ = tap("onboarding.continue")
        sleep(5); shot("onb-4-script")
        _ = tap("onboarding.useScript")
        sleep(2); shot("onb-5-voice")
        _ = tap("onboarding.continue")
        sleep(4); shot("onb-6-practice")
        try finish("-onboarding")
    }

    private func begin() throws {
        let env = ProcessInfo.processInfo.environment
        guard let folder = env["CUE_TOUR_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_TOUR_DIR to run the tour") }
        directory = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        tourName = env["CUE_TOUR_NAME"] ?? "tour"
        // CUE_TOUR_SEEDED=0 starts with an empty library (the first run), CUE_TOUR_NOAI=1 without Apple
        // Intelligence, CUE_TOUR_PRO=1 on the Pro plan.
        app = CueApp.launch(
            seeded: env["CUE_TOUR_SEEDED"] != "0", pro: env["CUE_TOUR_PRO"] == "1", ai: env["CUE_TOUR_NOAI"] == "1" ? .none : .stub,
            sampleVideo: true, appLanguage: env["CUE_TOUR_LANG"], contentSize: env["CUE_TOUR_SIZE"]
        )
        continueAfterFailure = true
        _ = app.buttons["ideaCard.submit"].waitForExistence(timeout: 20)
        sleep(1)
    }

    private func finish(_ suffix: String) throws {
        try misses.joined(separator: "\n").write(to: directory.appending(path: "\(tourName)\(suffix)-misses.txt"), atomically: true, encoding: .utf8)
    }

    // MARK: - Tour

    private func scripts() {
        shot("scripts")
        for chip in ["formatChip", "platformChip", "ideasChip"] {
            guard tap("ideaCard.\(chip)") else { continue }
            shot("scripts-\(chip)")
            closeSheet()
        }
        if tap("scripts.newButton") { shot("new-script"); closeSheet() }
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.'")).firstMatch
        if row.waitForExistence(timeout: 5) {
            row.tap()
            shot("script-shaped")
            shot("script-draft")
            if tap("page.menuButton") {
            shot("script-menu")
            // Tapping below everything closes the menu without choosing anything in it.
            app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.985)).tap()
            sleep(1)
        }
            if tap("page.platformChip") { shot("script-platform"); closeSheet() }
            _ = app.pageBackButton.exists ? { app.pageBackButton.tap(); return true }() : false
        } else { misses.append("scripts.row") }
    }

    private func voiceFlow() {
        guard tap("ideaCard.voiceChip") else { return }
        shot("voice-1-role")
        _ = tap("voiceSetup.role.personal")
        shot("voice-1-role-picked")
        _ = tap("voiceSetup.saveButton")
        shot("voice-2-topics")
        _ = tap("voiceSetup.niche.tech")
        _ = tap("voiceSetup.saveButton")
        shot("voice-3-audience")
        _ = tap("voiceSetup.audience.simple")
        _ = tap("voiceSetup.saveButton")
        shot("voice-4-tone")
        _ = tap("voiceSetup.tone.casual")
        _ = tap("voiceSetup.saveButton")
        sleep(1)
        shot("scripts-voice-set")
    }

    private func takesAndEditor() {
        tab(1)
        shot("takes")
        let list = app.segmentedControls["takes.layout"].buttons["List"]
        if list.waitForExistence(timeout: 4) {
            list.tap()
            sleep(1)
            shot("takes-list")
        } else {
            misses.append("takes.layout")
        }
        let video = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.'")).firstMatch
        if video.waitForExistence(timeout: 5) {
            video.tap()
            sleep(4)
            shot("review")
            if tap("review.shareButton") { shot("share"); closeSheet() }
            if tap("review.editButton") {
                sleep(5)
                shot("editor")
                if tap("edit.toolbar.audio") { shot("editor-audio") }
                if tap("edit.doneButton") { sleep(1); shot("editor-done"); app.swipeDown() }
                _ = tap("edit.backButton")
            }
            _ = tap("review.backButton")
        } else { misses.append("takes.video") }
    }

    private func profileAndSettings() {
        tab(3)
        shot("profile")
        app.swipeUp(); shot("profile-2"); app.swipeUp(); shot("profile-3")
        if tap("profile.upgradeButton") { sleep(1); shot("paywall"); _ = tap("paywall.closeButton") }
        tab(4)
        shot("settings")
        app.swipeUp(); shot("settings-2")
        app.swipeDown()
        for (id, label) in [("settings.recording", "recording"), ("settings.prompter", "prompter"), ("settings.remote", "remote")] {
            guard tap(id) else { continue }
            sleep(1)
            shot("settings-\(label)")
            app.swipeUp(); shot("settings-\(label)-2")
            app.navigationBars.buttons.firstMatch.tap()
        }
        if tap("settings.languageRegion") { shot("settings-language"); app.navigationBars.buttons.firstMatch.tap() }
        if tap("settings.privacy") { shot("settings-privacy"); app.navigationBars.buttons.firstMatch.tap() }
    }

    private func prompter() {
        tab(0)
        let record = app.buttons["row.recordButton"].firstMatch
        guard record.waitForExistence(timeout: 5) else { misses.append("row.recordButton"); return }
        record.tap()
        sleep(2)
        shot("prompter")
        for (id, label) in [("prompter.displayButton", "display"), ("prompter.setupButton", "this-take"), ("prompter.audioInputButton", "audio")] {
            guard tap(id) else { continue }
            shot("prompter-\(label)")
            closeSheet()
        }
        if tap("prompter.moreButton") { shot("prompter-more"); app.swipeDown() }
        if tap("prompter.cameraSettingsButton") { shot("prompter-camera"); closeSheet() }
        let voice = app.descendants(matching: .any)["prompter.scrollMode"].firstMatch.buttons["Voice"]
        if voice.exists { voice.tap(); shot("prompter-voice") }
        if app.buttons["Studio"].exists { app.buttons["Studio"].tap(); sleep(1); shot("prompter-studio"); app.buttons["Selfie"].tap(); sleep(1) }
        if tap("prompter.recordButton") {
            sleep(2)
            shot("prompter-recording")
            app.tap()
            shot("prompter-recording-bar")
            _ = tap("prompter.recordButton")
            sleep(2)
            shot("prompter-after-stop")
        }
    }

    // MARK: - Helpers

    private func tab(_ index: Int) {
        let bar = app.cueTabBar
        if bar.waitForExistence(timeout: 5) { bar.buttons.element(boundBy: index).tap(); sleep(1) } else { misses.append("tabBar") }
    }

    /// Taps a control by identifier; a missing one is written down, not a failure.
    @discardableResult
    private func tap(_ id: String) -> Bool {
        let element = app.descendants(matching: .any)[id].firstMatch
        guard element.waitForExistence(timeout: 4) else { misses.append(id); return false }
        var scrolls = 0
        while !element.isHittable, scrolls < 3 { app.swipeUp(); scrolls += 1 }
        guard element.isHittable else { misses.append("\(id) (not hittable)"); return false }
        element.tap()
        sleep(1)
        return true
    }

    private func closeSheet() {
        for id in ["sheet.closeButton", "display.doneButton", "logbook.doneButton"] where app.buttons[id].exists {
            app.buttons[id].tap(); sleep(1); return
        }
        let done = app.buttons["Done"]
        if done.exists, done.isHittable { done.tap(); sleep(1); return }
        app.swipeDown(); sleep(1)
    }

    private func shot(_ label: String) {
        count += 1
        let file = String(format: "%@-%02d-%@.png", tourName, count, label)
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: file))
        // The accessibility hierarchy beside each picture: where every text is, for `tools/contrast/audit.py`.
        try? app.debugDescription.write(to: directory.appending(path: file.replacingOccurrences(of: ".png", with: ".txt")), atomically: true, encoding: .utf8)
    }
}
