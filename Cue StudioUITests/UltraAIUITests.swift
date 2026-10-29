//
//  UltraAIUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Ultra AI on the Scripts screen and in Find inspiration, with the stub client (`-uiTestUltra`): picking it asks first, saying no keeps
/// Apple Intelligence, the star and the page say "Ultra AI", the written script carries its fact-check reminder, and a failed polish is told
/// without the draft becoming the script.
@MainActor
final class UltraAIUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func text(_ app: XCUIApplication, containing words: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", words)).firstMatch
    }

    private func pickUltra(_ app: XCUIApplication) {
        let chip = app.buttons["ideaCard.writerChip"]
        XCTAssertTrue(chip.exists(within: 15), "No writer chip where Ultra AI is offered")
        chip.tap()
        // "Ultra AI · 5 of 5 free left": the menu says how many are left.
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ultra AI")).firstMatch
        XCTAssertTrue(option.exists(within: 5), "The writer menu has no Ultra AI")
        option.tap()
    }

    /// Picking Ultra AI shows the disclosure first; allowing it puts the chip on Ultra AI, and the idea is drafted under a star that says so,
    /// into a page whose fact-check reminder names Ultra AI.
    func testTheDocksUltraAsksFirstThenWritesTheScript() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestStarTransition"])
        pickUltra(app)
        XCTAssertTrue(element(app, "ultra.consent").exists(within: 5), "Ultra AI was picked without asking")
        XCTAssertTrue(text(app, containing: "Google").exists, "The disclosure doesn't say who processes the request")
        let allow = app.buttons["ultra.consent.allow"]
        app.scroll(to: allow)
        allow.tap()
        let chip = app.buttons["ideaCard.writerChip"]
        XCTAssertTrue(chip.exists(within: 5))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Ultra AI"), evaluatedWith: chip)
        waitForExpectations(timeout: 5)
        let field = element(app, "ideaCard.field")
        field.tap()
        field.typeText("Why I stopped buying bottled water")
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(text(app, containing: "Drafting with Ultra AI").exists(within: 5), "The star doesn't say Ultra AI")
        XCTAssertTrue(element(app, "page.editor").exists(within: 20), "No page written by Ultra AI")
        XCTAssertTrue(text(app, containing: "Ultra AI can get facts wrong").exists(within: 5), "No Ultra AI fact-check reminder")
        // The words reach the editor as they are revealed: its value has them once the page has settled.
        let editor = element(app, "page.editor")
        expectation(for: NSPredicate(format: "value CONTAINS %@", "Ultra polished opening"), evaluatedWith: editor)
        waitForExpectations(timeout: 10)
        XCTAssertFalse(text(app, containing: "Gemini").exists, "The brand of the model is on screen")
    }

    /// On a script Ultra AI wrote, Improve's "Fit to time" says it is Ultra AI's, and fitting it puts Ultra's answer on the page.
    func testUltraFitsAScriptItWroteToTheTime() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"])
        pickUltra(app)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 5))
        field.tap()
        field.typeText("Why I stopped buying bottled water")
        app.buttons["ideaCard.submit"].tap()
        let editor = element(app, "page.editor")
        XCTAssertTrue(editor.exists(within: 20), "No page written by Ultra AI")
        expectation(for: NSPredicate(format: "value CONTAINS %@", "Ultra polished opening"), evaluatedWith: editor)
        waitForExpectations(timeout: 10)
        let improve = app.buttons["page.improveButton"]
        XCTAssertTrue(improve.exists(within: 5), "No Improve on a script Ultra AI wrote")
        improve.tap()
        let fit = app.buttons["improve.tool.fitToTime"]
        XCTAssertTrue(fit.exists(within: 5), "Improve has no Fit to time")
        XCTAssertTrue(fit.label.contains("Ultra AI"), "Fit to time doesn't say Ultra AI fits this script: \(fit.label)")
        fit.tap()
        expectation(for: NSPredicate(format: "value CONTAINS %@", "Ultra fitted script"), evaluatedWith: editor)
        waitForExpectations(timeout: 15)
        XCTAssertFalse(text(app, containing: "Gemini").exists, "The brand of the model is on screen")
    }

    /// From the second use of the AI the dock invites to Ultra AI with its free scripts; "Try it" asks first (saying the first five are free),
    /// and allowing it puts the chip on Ultra AI and ends the invitation.
    func testTheInvitationAsksFirstThenPicksUltra() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraInvite"])
        XCTAssertTrue(element(app, "ultra.invite").exists(within: 15), "No invitation on the dock after the AI was used")
        XCTAssertTrue(text(app, containing: "5 free scripts").exists, "The invitation doesn't say the scripts are free")
        app.buttons["ultra.invite.try"].tap()
        XCTAssertTrue(element(app, "ultra.consent").exists(within: 5), "Ultra AI was tried without asking")
        XCTAssertTrue(text(app, containing: "Your first 5 scripts are free.").exists, "The permission doesn't say what is free")
        let allow = app.buttons["ultra.consent.allow"]
        app.scroll(to: allow)
        allow.tap()
        let chip = app.buttons["ideaCard.writerChip"]
        expectation(for: NSPredicate(format: "label CONTAINS %@", "Ultra AI"), evaluatedWith: chip)
        waitForExpectations(timeout: 5)
        XCTAssertTrue(element(app, "ultra.invite").waitForNonExistence(timeout: 5), "The invitation stayed once Ultra AI was allowed")
    }

    /// Closed on the dock, the invitation is gone from Find inspiration too.
    func testClosingTheInvitationClosesItEverywhere() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraInvite", "-uiTestTopics", "food"])
        XCTAssertTrue(element(app, "ultra.invite").exists(within: 15))
        app.buttons["ultra.invite.close"].tap()
        XCTAssertTrue(element(app, "ultra.invite").waitForNonExistence(timeout: 5), "The invitation didn't close")
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        XCTAssertFalse(element(app, "ultra.invite").exists, "Closed on the dock, the invitation is still in Find inspiration")
    }

    /// With the free scripts used up, picking Ultra AI offers Cue Pro (its own calm Pro, honest about the trial), and the chip stays on Apple
    /// Intelligence.
    func testWithNoFreeScriptsLeftUltraOffersCuePro() {
        let app = CueApp.launch(
            seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestUltraScriptsLeft", "0"]
        )
        pickUltra(app)
        XCTAssertTrue(text(app, containing: "Keep writing with Ultra AI.").exists(within: 5), "No Cue Pro when the free scripts are used up")
        XCTAssertTrue(text(app, containing: "from the first paid month").exists, "The Pro doesn't say when Ultra AI's monthly scripts start")
        app.buttons["paywall.closeButton"].tap()
        let chip = app.buttons["ideaCard.writerChip"]
        XCTAssertTrue(chip.exists(within: 5))
        XCTAssertTrue(chip.label.contains("Apple Intelligence"), chip.label)
    }

    /// "Keep Apple Intelligence" on the disclosure: nothing is allowed, and the chip stays on Apple Intelligence.
    func testSayingNoKeepsAppleIntelligence() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra"])
        pickUltra(app)
        XCTAssertTrue(element(app, "ultra.consent").exists(within: 5))
        let decline = app.buttons["ultra.consent.decline"]
        app.scroll(to: decline)
        decline.tap()
        let chip = app.buttons["ideaCard.writerChip"]
        XCTAssertTrue(chip.exists(within: 5))
        XCTAssertTrue(chip.label.contains("Apple Intelligence"), chip.label)
    }

    /// Find inspiration's "Draft with Ultra AI": the card's idea is written by Ultra AI, and the dock's own draft is untouched.
    func testFindInspirationDraftsWithUltra() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestTopics", "food"])
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists(within: 15))
        app.buttons["ideaCard.inspirationButton"].tap()
        let ultra = app.buttons["inspiration.writeUltra"]
        XCTAssertTrue(ultra.exists(within: 5), "No Ultra AI button where Ultra AI is offered")
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        ultra.tap()
        XCTAssertTrue(element(app, "page.editor").exists(within: 20), "No page written from the idea")
        XCTAssertTrue(text(app, containing: "Ultra AI can get facts wrong").exists(within: 5))
    }

    /// The polish fails: a toast says so, and no page opens with the unfinished draft.
    func testAFailedPolishIsToldAndTheDraftIsNeverTheScript() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestUltraReviewFails"])
        pickUltra(app)
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(EditorApp.toastSays(app, "couldn’t polish", timeout: 15), "The failure wasn't told")
        XCTAssertFalse(text(app, containing: "Ultra draft paragraph").exists, "The unfinished draft was shown as the script")
    }

    // MARK: - Pictures for the contrast audit

    /// The pictures and hierarchies `tools/contrast/audit.py` measures (`TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`): the dock's chip on Ultra AI,
    /// the permission sheet (top and buttons), the star, the written page with its reminder, Find inspiration's button and Settings.
    func testCaptureUltraAIScreensForTheContrastAudit() throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func shot(_ app: XCUIApplication, _ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
            try app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
        }
        var app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestStarTransition", "-uiTestUltraSlow", "-uiTestTopics", "food"])
        pickUltra(app)
        XCTAssertTrue(element(app, "ultra.consent").exists(within: 5))
        try shot(app, "ultra_01_consent")
        element(app, "ultra.consent").swipeUp()
        try shot(app, "ultra_02_consent-buttons")
        element(app, "ultra.consent.sends").tap()
        try shot(app, "ultra_03_consent-sends")
        let allow = app.buttons["ultra.consent.allow"]
        app.scroll(to: allow)
        allow.tap()
        try shot(app, "ultra_04_dock-chip")
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(text(app, containing: "Drafting with Ultra AI").exists(within: 5))
        try shot(app, "ultra_05_star")
        XCTAssertTrue(element(app, "page.editor").exists(within: 30))
        try shot(app, "ultra_06_page")
        app.pageBackButton.tap()
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(app.buttons["inspiration.writeUltra"].exists(within: 5))
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        try shot(app, "ultra_07_inspiration")
        // Settings from a fresh launch: the sheet's own scroll can take a swipe meant to close it.
        app.terminate()
        app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"])
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.exists(within: 10))
        settings.tap()
        let privacy = element(app, "settings.privacy")
        app.scroll(to: privacy)
        privacy.tap()
        XCTAssertTrue(element(app, "privacy.ultra").exists(within: 5))
        try shot(app, "ultra_08_settings-privacy")
    }

    /// The invitation and what follows the free scripts, for the same audit: the dock's line, Find inspiration's card, the Profile's plan card
    /// with Ultra AI's line, My Cue Voice's card, the regular Pro with Ultra AI's line, and the calm Pro once the free scripts are used up.
    func testCaptureUltraAIInvitationForTheContrastAudit() throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func shot(_ app: XCUIApplication, _ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
            try app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
        }
        var app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraInvite", "-uiTestTopics", "food"])
        XCTAssertTrue(element(app, "ultra.invite").exists(within: 15))
        try shot(app, "ultra_09_dock-invite")
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        XCTAssertTrue(element(app, "ultra.invite").exists(within: 5))
        try shot(app, "ultra_10_inspiration-invite")
        app.swipeDown(velocity: .fast)
        let profile = app.cueTabBar.buttons["Profile"]
        XCTAssertTrue(profile.exists(within: 10))
        profile.tap()
        XCTAssertTrue(element(app, "profile.ultraAllowance").exists(within: 5))
        try shot(app, "ultra_11_profile-plan")
        let edit = app.buttons["profile.editVoice"]
        if edit.exists(within: 3) {
            app.scroll(to: edit)
            edit.tap()
            XCTAssertTrue(element(app, "voicePage").exists(within: 5))
            let card = element(app, "ultra.invite")
            app.scroll(to: card)
            try shot(app, "ultra_12_voice-invite")
            app.navigationBars.buttons.firstMatch.tap()
        }
        let upgrade = app.buttons["profile.upgradeButton"]
        app.scroll(to: upgrade)
        upgrade.tap()
        XCTAssertTrue(text(app, containing: "Ultra AI scripts a month").exists(within: 8))
        try shot(app, "ultra_13_pro-benefits")
        app.terminate()
        app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestUltraScriptsLeft", "0"])
        pickUltra(app)
        XCTAssertTrue(text(app, containing: "Keep writing with Ultra AI.").exists(within: 5))
        try shot(app, "ultra_14_pro-ultra")
    }
}
