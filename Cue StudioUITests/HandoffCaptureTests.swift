//
//  HandoffCaptureTests.swift
//  Cue StudioUITests
//

import XCTest

/// Pictures of the screens of `design/cue-v30/handoff-hoje`, named after the handoff's PNGs (`11.1_root`, `9.2_live-2026`…), to set
/// beside them. Opt in with `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`; nothing is asserted beyond each screen opening.
@MainActor
final class HandoffCaptureTests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func requireFolder() throws -> URL {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        return folder
    }

    private func shot(_ app: XCUIApplication, _ name: String, wait: UInt32 = 1) throws {
        let folder = try requireFolder()
        if wait > 0 { sleep(wait) }
        try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
        // The hierarchy beside the picture, for `tools/contrast/audit.py`.
        try app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Settings, with the row `id` opened.
    private func open(_ app: XCUIApplication, _ id: String) {
        let row = element(app, id)
        app.scroll(to: row)
        row.tap()
    }

    private func settings(_ app: XCUIApplication) {
        let tab = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    private func back(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
    }

    // MARK: - 1 · Settings (11.1)

    func test11_1_Settings() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: true)
        settings(app)
        try shot(app, "11.1_root")
        for (id, name, bar) in [
            ("settings.recording", "11.1_recording", "Recording"),
            ("settings.prompter", "11.1_prompter", "Prompter"),
            ("settings.remote", "11.1_remote", "Remote"),
            ("settings.personalize", "11.1_personalize", "Personalize"),
            ("settings.languageRegion", "11.1_language-region", "Language & Region"),
            ("settings.privacy", "11.1_privacy-ai-data", "Privacy & AI data"),
            ("settings.acknowledgements", "11.1_acknowledgements", "Acknowledgements"),
        ] {
            open(app, id)
            XCTAssertTrue(app.navigationBars[bar].waitForExistence(timeout: 5), bar)
            try shot(app, name)
            back(app)
        }
    }

    func test11_1_SubPages() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: true)
        settings(app)
        open(app, "settings.recording")
        let resolution = element(app, "settings.resolution")
        resolution.tap()
        try shot(app, "11.1_menu-open")
        app.buttons["1080p"].firstMatch.tap()
        open(app, "settings.microphone")
        try shot(app, "11.1_microphone")
        back(app)
        back(app)
        open(app, "settings.prompter")
        open(app, "settings.font")
        try shot(app, "11.1_font")
        back(app)
        open(app, "settings.socialSafeZone")
        try shot(app, "11.1_safe-zone")
        back(app)
        back(app)
        open(app, "settings.privacy")
        open(app, "settings.permissions")
        try shot(app, "11.1_permissions")
        back(app)
        element(app, "settings.deleteData").tap()
        try shot(app, "11.1_reset-confirm")
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.1, dy: 0.85)).tap()
        back(app)
        open(app, "settings.personalize")
        open(app, "settings.appIcon")
        try shot(app, "11.1_app-icon")
    }

    func test11_1_Search() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: true)
        settings(app)
        let field = app.textFields["settings.searchField"]
        field.tap()
        field.typeText("mirror")
        try shot(app, "11.1_search-result")
        field.clearAndType("zzzz")
        try shot(app, "11.1_search-empty")
    }

    // MARK: - 1 · Onboarding (1.1, 1.2)

    /// The star opening of 1.1, a picture every half second from the launch (the board's 14 s loop plays once here, about 8 s).
    func test1_1_Welcome() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: false, animations: true, extraArguments: ["-uiTestOnboarding", "-uiTestWelcomeOpening"])
        for step in 0..<20 {
            try shot(app, String(format: "1.1_%02d", step), wait: 0)
            usleep(300_000)
        }
        let start = app.buttons["onboarding.getStarted"]
        XCTAssertTrue(start.waitForExistence(timeout: 12))
        try shot(app, "1.1_final", wait: 1)
    }

    /// The star scene of 1.1 held still at the seconds of the board where something happens (`-uiTestWelcomeAt`).
    func test1_1_Frames() throws {
        _ = try requireFolder()
        for second in [0.9, 1.15, 1.35, 1.6, 1.95, 2.3, 2.8, 3.1, 3.7, 4.3, 5.1, 5.4, 5.9, 6.4, 7.0] {
            let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestOnboarding", "-uiTestWelcomeAt", String(second)])
            try shot(app, "1.1_at_" + String(format: "%04.2f", second), wait: 1)
            app.terminate()
        }
    }

    // MARK: - 4 · Pro (11.4)

    /// The regular Pro held still at the seconds of its opening, then the end of it, and the calm Pro from the free exports.
    func test11_4_Pro() throws {
        _ = try requireFolder()
        for second in [0.3, 0.6, 0.9, 1.2, 1.4, 1.6, 1.9, 2.4] {
            let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestProAt", String(second)])
            app.cueTabBar.buttons["Profile"].tap()
            let upgrade = element(app, "profile.upgradeButton")
            app.scroll(to: upgrade)
            upgrade.tap()
            XCTAssertTrue(element(app, "paywall.closeButton").waitForExistence(timeout: 8))
            try shot(app, "11.4_at_" + String(format: "%03.1f", second), wait: 2)
            app.terminate()
        }
        let calm = CueApp.launch(seeded: true, extraArguments: ["-uiTestExportsLeft", "0"])
        calm.cueTabBar.buttons["Takes"].tap()
        let row = calm.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        XCTAssertTrue(element(calm, "review.exportNotice").waitForExistence(timeout: 5))
        try shot(calm, "6.3_exports-none", wait: 1)
        calm.buttons["review.saveButton"].tap()
        XCTAssertTrue(calm.buttons["exportReady.notNow"].waitForExistence(timeout: 5))
        try shot(calm, "8.1_your-video-is-ready", wait: 1)
        calm.buttons["exportReady.seePro"].tap()
        XCTAssertTrue(calm.buttons["paywall.buyButton"].waitForExistence(timeout: 8))
        try shot(calm, "11.4_pro-calm", wait: 1)
    }

    // MARK: - 5 · Your universe (9.2)

    func test9_2_Universe() throws {
        _ = try requireFolder()
        func open(_ data: String) -> XCUIApplication {
            let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestUniverse", data])
            app.cueTabBar.buttons["Profile"].tap()
            let link = element(app, "profile.universeLink")
            XCTAssertTrue(link.waitForExistence(timeout: 10))
            link.tap()
            XCTAssertTrue(element(app, "universe.screen").waitForExistence(timeout: 5))
            return app
        }
        let year = Calendar.current.component(.year, from: .now)
        let live = open("sample")
        try shot(live, "9.2_live", wait: 2)
        element(live, "universe.planet.tiktok").tap()
        XCTAssertTrue(live.buttons["universe.planetSeeInTakes"].waitForExistence(timeout: 5))
        try shot(live, "9.2_planet-popover", wait: 1)
        // The first tap only closes the popover.
        live.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        sleep(1)
        element(live, "universe.year.\(year - 1)").tap()
        try shot(live, "9.2_sealed", wait: 2)
        element(live, "universe.year.\(year)").tap()
        element(live, "universe.share").tap()
        XCTAssertTrue(element(live, "universeShare.kind").waitForExistence(timeout: 5))
        try shot(live, "9.2_share-sheet", wait: 3)
        live.buttons["sheet.closeButton"].tap()
        element(live, "universe.reviewRow").tap()
        XCTAssertTrue(element(live, "yearInReview.screen").waitForExistence(timeout: 5))
        try shot(live, "9.2_story-1", wait: 1)
        for slide in 2...5 {
            element(live, "yearInReview.next").tap()
            try shot(live, "9.2_story-\(slide)", wait: 1)
        }
        let newAccount = open("newAccount")
        try shot(newAccount, "9.2_new-account", wait: 2)
        let newYear = open("newYear")
        try shot(newYear, "9.2_new-year", wait: 2)
    }

    // MARK: - 6 · Takes (6.2)

    func test6_2_Takes() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: true, sampleVideo: true)
        app.cueTabBar.buttons["Takes"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 15))
        try shot(app, "6.2_takes", wait: 2)
    }

    // MARK: - 4 · Profile (9.1)

    func test9_1_Profile() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUniverse", "sample"])
        app.cueTabBar.buttons["Profile"].tap()
        let identity = element(app, "profile.creatorCard")
        XCTAssertTrue(identity.waitForExistence(timeout: 10))
        try shot(app, "9.1_default", wait: 2)
        identity.press(forDuration: 0.8)
        XCTAssertTrue(app.buttons["Edit profile"].waitForExistence(timeout: 5))
        try shot(app, "9.1_context-menu", wait: 1)
        app.buttons["Edit profile"].tap()
        XCTAssertTrue(element(app, "editProfile.doneButton").waitForExistence(timeout: 5))
        try shot(app, "9.1_edit-profile", wait: 1)
        app.buttons["editProfile.cancelButton"].tap()
        let empty = CueApp.launch(seeded: false, extraArguments: ["-uiTestUniverse", "newAccount"])
        empty.cueTabBar.buttons["Profile"].tap()
        XCTAssertTrue(element(empty, "profile.creatorCard").waitForExistence(timeout: 10))
        try shot(empty, "9.1_new-account", wait: 2)
    }

    // MARK: - 4 · Script page (4.1, 4.2)

    /// The page with Record in the system's bottom bar, then the keyboard with the cues in its own bar.
    func test4_1_ScriptPage() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        XCTAssertTrue(app.buttons["detail.recordButton"].waitForExistence(timeout: 10))
        try shot(app, "4.1_page", wait: 1)
        element(app, "page.editor").tap()
        XCTAssertTrue(app.buttons["page.addCueButton"].waitForExistence(timeout: 5))
        try shot(app, "4.2_cues-bar", wait: 1)
    }

    // MARK: - 6 · Share to universe (8.1, 8.2, 6.3)

    func test8_1_ShareToUniverse() throws {
        _ = try requireFolder()
        // Real animations: the networks' sheet only comes back after the share sheet has animated away.
        let app = CueApp.launch(seeded: true, sampleVideo: true, animations: true, extraArguments: ["-uiTestFakeShareSheet", "-uiTestUniverse", "sample"])
        app.cueTabBar.buttons["Takes"].tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()
        XCTAssertTrue(app.buttons["review.shareButton"].waitForExistence(timeout: 10))
        try shot(app, "6.3_review", wait: 1)
        app.buttons["review.shareButton"].tap()
        XCTAssertTrue(element(app, "shareFlow.start").waitForExistence(timeout: 120))
        element(app, "shareFlow.network.reels").tap()
        element(app, "shareFlow.network.linkedin").tap()
        try shot(app, "8.1_pick-networks", wait: 1)
        app.buttons["shareFlow.start"].tap()
        XCTAssertTrue(waitAllowingPhotos(for: app.buttons["shareFlow.explainerStart"]))
        try shot(app, "8.1_explainer-3-networks", wait: 1)
        app.buttons["shareFlow.explainerStart"].tap()
        XCTAssertTrue(element(app, "shareFlow.step").waitForExistence(timeout: 5))
        try shot(app, "8.1_queue-step", wait: 1)
        app.buttons["shareFlow.send"].tap()
        XCTAssertTrue(app.buttons["debug.share.complete"].waitForExistence(timeout: 10))
        app.buttons["debug.share.complete"].tap()
        XCTAssertTrue(element(app, "shareFlow.confirm").waitForExistence(timeout: 10))
        try shot(app, "8.1_posted-question", wait: 1)
        app.buttons["shareFlow.live"].tap()
        XCTAssertTrue(element(app, "shareFlow.step").waitForExistence(timeout: 5))
        app.buttons["shareFlow.postLater"].tap()
        // Post later is a menu (a reminder or none): "No reminder" leaves the network for later, as the button did.
        XCTAssertTrue(app.buttons["shareFlow.noReminder"].waitForExistence(timeout: 5))
        app.buttons["shareFlow.noReminder"].tap()
        XCTAssertTrue(element(app, "shareFlow.step").waitForExistence(timeout: 5))
        app.buttons["shareFlow.send"].tap()
        app.buttons["debug.share.complete"].tap()
        app.buttons["shareFlow.live"].tap()
        XCTAssertTrue(element(app, "sendoff.sheet").waitForExistence(timeout: 20))
        sleep(5)
        try shot(app, "8.2_2-networks", wait: 1)
        app.buttons["sendoff.done"].tap()
        try shot(app, "debug_after_sendoff", wait: 2)
        XCTAssertTrue(element(app, "review.postLater").waitForExistence(timeout: 10))
        try shot(app, "6.3_post-later", wait: 1)
    }

    func test8_1_Ready() throws {
        _ = try requireFolder()
        for (name, left) in [("save-video-share-icon", "3"), ("last-free-export", "1")] {
            let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestExportsLeft", left, "-uiTestFakeShareSheet"])
            app.cueTabBar.buttons["Takes"].tap()
            let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap()
            XCTAssertTrue(app.buttons["review.shareButton"].waitForExistence(timeout: 10))
            if name == "last-free-export" { try shot(app, "6.3_last-free-export", wait: 1) }
            app.buttons["review.shareButton"].tap()
            XCTAssertTrue(element(app, "shareFlow.start").waitForExistence(timeout: 120))
            app.buttons["sheet.closeButton"].tap()
            XCTAssertTrue(app.buttons["ready.shareButton"].waitForExistence(timeout: 10))
            try shot(app, "8.1_\(name)", wait: 1)
            app.terminate()
        }
    }

    func test8_1_ContinuePosting() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestShareQueue"])
        XCTAssertTrue(element(app, "continuePosting.card").waitForExistence(timeout: 15))
        try shot(app, "3.2_continue-posting-card", wait: 1)
        app.cueTabBar.buttons["Takes"].tap()
        XCTAssertTrue(element(app, "continuePosting.card").waitForExistence(timeout: 5))
        try shot(app, "6.2_continue-posting-card", wait: 1)
    }

    // MARK: - 7 · Linked screens (8.3, 1.7, 9.3, 6.2) and 8.2

    func test7_LinkedScreens() throws {
        _ = try requireFolder()
        func openTake(_ args: [String]) -> XCUIApplication {
            let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: args)
            app.cueTabBar.buttons["Takes"].tap()
            let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap()
            return app
        }
        let milestone = openTake(["-uiTestMilestone", "25", "-uiTestUniverse", "sample", "-uiTestStoryAt", "6"])
        XCTAssertTrue(element(milestone, "milestone.sheet").waitForExistence(timeout: 15))
        try shot(milestone, "8.3_milestone", wait: 1)
        let firstStar = openTake(["-uiTestFirstStar", "-uiTestStoryAt", "7.5"])
        XCTAssertTrue(element(firstStar, "firstStar.sheet").waitForExistence(timeout: 15))
        try shot(firstStar, "1.7_first-star", wait: 1)
        let voice = CueApp.launch(seeded: true, extraArguments: ["-uiTestUniverse", "sample"])
        voice.cueTabBar.buttons["Profile"].tap()
        let edit = voice.buttons["Edit voice"]
        XCTAssertTrue(edit.waitForExistence(timeout: 10))
        edit.tap()
        XCTAssertTrue(element(voice, "voicePage").waitForExistence(timeout: 10))
        try shot(voice, "9.3_my-cue-voice", wait: 1)
        let takes = CueApp.launch(seeded: true, extraArguments: ["-uiTestUniverse", "sample"])
        takes.cueTabBar.buttons["Profile"].tap()
        element(takes, "profile.universeLink").tap()
        XCTAssertTrue(element(takes, "universe.planet.tiktok").waitForExistence(timeout: 10))
        element(takes, "universe.planet.tiktok").tap()
        XCTAssertTrue(takes.buttons["universe.planetSeeInTakes"].waitForExistence(timeout: 5))
        takes.buttons["universe.planetSeeInTakes"].tap()
        XCTAssertTrue(element(takes, "takes.scopeChip").waitForExistence(timeout: 10))
        try shot(takes, "6.2_takes-from-planet", wait: 1)
    }

    /// The 1.7 and 8.3 stories at fixed seconds, to compare each keyframe with the board.
    func test7_StoryFrames() throws {
        _ = try requireFolder()
        for second in ["0.5", "1.3", "2.3", "3.5", "4.6", "6.0", "7.5"] {
            let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: ["-uiTestFirstStar", "-uiTestStoryAt", second])
            app.cueTabBar.buttons["Takes"].tap()
            let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap()
            XCTAssertTrue(element(app, "firstStar.sheet").waitForExistence(timeout: 15))
            try shot(app, "1.7_at_\(second)", wait: 1)
            app.terminate()
        }
        for second in ["0.8", "1.3", "1.7", "2.2"] {
            let arguments = ["-uiTestMilestone", "25", "-uiTestUniverse", "sample", "-uiTestStoryAt", second]
            let app = CueApp.launch(seeded: true, sampleVideo: true, extraArguments: arguments)
            app.cueTabBar.buttons["Takes"].tap()
            let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
            XCTAssertTrue(row.waitForExistence(timeout: 10))
            row.tap()
            XCTAssertTrue(element(app, "milestone.sheet").waitForExistence(timeout: 15))
            try shot(app, "8.3_at_\(second)", wait: 1)
            app.terminate()
        }
    }

    func test8_2_SendOffFrames() throws {
        _ = try requireFolder()
        for (name, extra) in [("3-networks", ["3"]), ("1-network", [String]())] {
            for second in name == "1-network" ? [4.0] : [0.3, 1.0, 1.7, 2.4, 4.0] {
                let app = CueApp.launch(
                    seeded: true, sampleVideo: true, animations: true,
                    extraArguments: ["-uiTestFakeShareSheet", "-uiTestUniverse", "sample", "-uiTestSendOffAt", String(second)]
                )
                app.cueTabBar.buttons["Takes"].tap()
                let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
                XCTAssertTrue(row.waitForExistence(timeout: 10))
                row.tap()
                app.buttons["review.shareButton"].tap()
                XCTAssertTrue(element(app, "shareFlow.start").waitForExistence(timeout: 120))
                if !extra.isEmpty {
                    element(app, "shareFlow.network.reels").tap()
                    element(app, "shareFlow.network.linkedin").tap()
                }
                app.buttons["shareFlow.start"].tap()
                if !extra.isEmpty {
                    XCTAssertTrue(waitAllowingPhotos(for: app.buttons["shareFlow.explainerStart"]))
                    app.buttons["shareFlow.explainerStart"].tap()
                }
                for _ in 0..<(extra.isEmpty ? 1 : 3) {
                    XCTAssertTrue(waitAllowingPhotos(for: app.buttons["shareFlow.send"]))
                    app.buttons["shareFlow.send"].tap()
                    XCTAssertTrue(app.buttons["debug.share.complete"].waitForExistence(timeout: 10))
                    app.buttons["debug.share.complete"].tap()
                    XCTAssertTrue(element(app, "shareFlow.confirm").waitForExistence(timeout: 10))
                    app.buttons["shareFlow.live"].tap()
                }
                XCTAssertTrue(element(app, "sendoff.sheet").waitForExistence(timeout: 20))
                try shot(app, "8.2_\(name)_at_\(second)", wait: 1)
                app.terminate()
            }
        }
    }

    /// 1.2: pick a topic and watch it become a world, a picture about every 0.3 s.
    func test1_2_Topics() throws {
        _ = try requireFolder()
        let app = CueApp.launch(seeded: false, animations: true, extraArguments: ["-uiTestOnboarding"])
        app.buttons["onboarding.getStarted"].tap()
        XCTAssertTrue(element(app, "onboarding.topic.niche.food").waitForExistence(timeout: 10))
        try shot(app, "1.2_00_entry", wait: 0)
        usleep(900_000)
        try shot(app, "1.2_01_before", wait: 0)
        element(app, "onboarding.topic.niche.food").tap()
        for step in 0..<12 {
            try shot(app, String(format: "1.2_tap_%02d", step), wait: 0)
            usleep(150_000)
        }
        element(app, "onboarding.topic.niche.fitness").tap()
        element(app, "onboarding.topic.niche.tech").tap()
        sleep(4)
        try shot(app, "1.2_final", wait: 0)
    }
}

private extension XCUIElement {
    func clearAndType(_ text: String) {
        tap()
        if let current = value as? String {
            typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: current.count))
        }
        typeText(text)
    }
}
