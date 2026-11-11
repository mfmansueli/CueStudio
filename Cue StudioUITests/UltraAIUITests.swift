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
        // "Ultra AI · 3 of 3 free left": the menu says how many are left.
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
        XCTAssertTrue(text(app, containing: "Anthropic").exists, "The disclosure doesn’t say who processes the request")
        let allow = app.buttons["ultra.consent.allow"]
        app.scroll(to: allow)
        allow.tap()
        let chip = app.buttons["ideaCard.writerChip"]
        XCTAssertTrue(chip.exists(within: 5))
        XCTAssertTrue(chip.matches(NSPredicate(format: "label CONTAINS %@", "Ultra AI"), within: 5))
        let field = element(app, "ideaCard.field")
        field.tap()
        field.typeText("Why I stopped buying bottled water")
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(text(app, containing: "Drafting with Ultra AI").exists(within: 5), "The star doesn't say Ultra AI")
        XCTAssertTrue(element(app, "page.editor").exists(within: 20), "No page written by Ultra AI")
        XCTAssertTrue(text(app, containing: "Ultra AI can get facts wrong").exists(within: 5), "No Ultra AI fact-check reminder")
        // The words reach the editor as they are revealed: its value has them once the page has settled.
        let editor = element(app, "page.editor")
        XCTAssertTrue(editor.matches(NSPredicate(format: "value CONTAINS %@", "Ultra polished opening"), within: 10))
        XCTAssertFalse(text(app, containing: "Gemini").exists, "The brand of the model is on screen")
    }

    /// On a script Ultra AI wrote, every touch-up is Apple Intelligence's (owner, 01/11/2026: Ultra writes, it never touches up): Improve says
    /// so, its Fit to time doesn't name Ultra AI, and fitting puts Apple Intelligence's answer on the page, not a second call to Ultra AI.
    func testEveryTouchUpOnAnUltraScriptIsAppleIntelligences() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"])
        pickUltra(app)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 5))
        field.tap()
        field.typeText("Why I stopped buying bottled water")
        app.buttons["ideaCard.submit"].tap()
        let editor = element(app, "page.editor")
        XCTAssertTrue(editor.exists(within: 20), "No page written by Ultra AI")
        XCTAssertTrue(editor.matches(NSPredicate(format: "value CONTAINS %@", "Ultra polished opening"), within: 10))
        let improve = app.buttons["page.improveButton"]
        XCTAssertTrue(improve.exists(within: 5), "No Improve on a script Ultra AI wrote")
        improve.tap()
        XCTAssertTrue(app.staticTexts["Apple Intelligence · Private Cloud Compute"].exists(within: 5), "Improve doesn't say Apple Intelligence does it")
        let fit = app.buttons["improve.tool.fitToTime"]
        XCTAssertTrue(fit.exists(within: 5), "Improve has no Fit to time")
        XCTAssertFalse(fit.label.contains("Ultra AI"), "Fit to time still names Ultra AI: \(fit.label)")
        fit.tap()
        XCTAssertTrue(editor.matches(NSPredicate(format: "value CONTAINS %@", "Rewritten with fitToTime"), within: 15))
        XCTAssertFalse(editor.matches(NSPredicate(format: "value CONTAINS %@", "Ultra fitted script"), within: 1))
    }

    /// A script Ultra AI wrote past the network's top whose own fit failed (`-uiTestUltraLong`): the length bar says so under its track and offers
    /// Apple Intelligence's "Fit to time"; Record's "A bit long" question makes it shorter the same way.
    func testTheLengthBarSaysAnUltraScriptIsPastTheIdealAndFitsIt() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestUltraLong"])
        pickUltra(app)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 5))
        field.tap()
        field.typeText("Why I stopped buying bottled water")
        app.buttons["ideaCard.submit"].tap()
        let editor = element(app, "page.editor")
        XCTAssertTrue(editor.exists(within: 20), "No page written by Ultra AI")
        XCTAssertTrue(editor.matches(NSPredicate(format: "value CONTAINS %@", "Ultra long paragraph"), within: 15))
        let past = element(app, "page.lengthBar.past")
        XCTAssertTrue(past.exists(within: 5), "The length bar doesn't say the script is past the ideal")
        XCTAssertTrue(past.label.contains("TikTok"), "The line doesn't name the platform: \(past.label)")
        let fit = app.buttons["page.lengthBar.fit"]
        XCTAssertTrue(fit.exists && !fit.label.contains("Ultra AI"), "The bar's fit still names Ultra AI: \(fit.label)")
        // Record rises once the words have landed (the 0.7 s hand-over): tapped mid-rise, it isn't there yet.
        let record = app.buttons["detail.recordButton"]
        record.waitUntilStill()
        record.tap()
        let shorter = app.buttons["page.nudge.shorter"]
        XCTAssertTrue(shorter.exists(within: 5), "No \"A bit long\" question")
        XCTAssertFalse(shorter.label.contains("Ultra AI"), "The nudge's Make it shorter still names Ultra AI: \(shorter.label)")
        shorter.tap()
        XCTAssertTrue(editor.matches(NSPredicate(format: "value CONTAINS %@", "Rewritten with fitToTime"), within: 15))
        XCTAssertFalse(text(app, containing: "Gemini").exists, "The brand of the model is on screen")
    }

    /// Settings › Privacy & AI data › What Ultra AI sends: what goes to Anthropic, what never does, what Anthropic does with it, and the requests
    /// word for word (App Review 5.1.2(i)); the consent stays one line.
    func testPrivacyHasEverythingUltraAISends() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"])
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.exists(within: 10))
        settings.tap()
        let privacy = element(app, "settings.privacy")
        app.scroll(to: privacy)
        privacy.tap()
        let detail = element(app, "privacy.ultraDetail")
        app.scroll(to: detail)
        detail.tap()
        XCTAssertTrue(element(app, "privacy.ultraDetail.screen").exists(within: 5))
        XCTAssertTrue(text(app, containing: "The draft between writing steps").exists, "The draft isn't listed as sent")
        // Fit to time on the page is Apple Intelligence's: nothing the creator edits goes back to Ultra AI.
        XCTAssertFalse(text(app, containing: "With Fit to time").exists, "Fit to time is listed as sent, but it never goes to Ultra AI")
        // Lower down the list, which only builds the rows on screen.
        let training = text(app, containing: "doesn’t use it to train")
        app.scroll(to: training)
        XCTAssertTrue(training.exists, "What Anthropic does with it is missing")
        XCTAssertTrue(text(app, containing: "up to 2 years").exists, "Anthropic's longer retention of a flagged request is missing")
        let requests = element(app, "privacy.ultraRequests")
        app.scroll(to: requests)
        requests.tap()
        XCTAssertTrue(element(app, "ultra.payload.draft").exists(within: 5), "The requests aren't shown word for word")
        XCTAssertFalse(text(app, containing: "Gemini").exists, "The brand of the model is on screen")
    }

    /// From the second use of the AI the dock invites to Ultra AI with its free scripts; "Try it" asks first (saying the first three are free),
    /// and allowing it puts the chip on Ultra AI and ends the invitation.
    func testTheInvitationAsksFirstThenPicksUltra() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraInvite"])
        XCTAssertTrue(element(app, "ultra.invite").exists(within: 15), "No invitation on the dock after the AI was used")
        XCTAssertTrue(text(app, containing: "3 free scripts").exists, "The invitation doesn't say the scripts are free")
        app.buttons["ultra.invite.try"].tap()
        XCTAssertTrue(element(app, "ultra.consent").exists(within: 5), "Ultra AI was tried without asking")
        XCTAssertTrue(text(app, containing: "Your first 3 scripts are free.").exists, "The permission doesn't say what is free")
        let allow = app.buttons["ultra.consent.allow"]
        app.scroll(to: allow)
        allow.tap()
        let chip = app.buttons["ideaCard.writerChip"]
        XCTAssertTrue(chip.matches(NSPredicate(format: "label CONTAINS %@", "Ultra AI"), within: 5))
        XCTAssertTrue(element(app, "ultra.invite").isGone(within: 5), "The invitation stayed once Ultra AI was allowed")
    }

    /// Closed on the dock, the invitation is gone from Find inspiration too: its "Draft with Ultra AI" no longer says the scripts are free.
    func testClosingTheInvitationClosesItEverywhere() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraInvite", "-uiTestTopics", "food"])
        XCTAssertTrue(element(app, "ultra.invite").exists(within: 15))
        app.buttons["ultra.invite.close"].tap()
        XCTAssertTrue(element(app, "ultra.invite").isGone(within: 5), "The invitation didn't close")
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        let ultra = app.buttons["inspiration.writeUltra"]
        XCTAssertTrue(ultra.exists(within: 5))
        XCTAssertFalse(ultra.label.contains("free"), "Closed on the dock, the invitation is still in Find inspiration: \(ultra.label)")
    }

    /// In Find inspiration the invitation is no card above the idea (it pushed the idea under the actions): the sheet's own "Draft with
    /// Ultra AI" says "· 3 free", the idea stays whole above the actions, and the button asks first like every invitation.
    func testFindInspirationCarriesTheInvitationOnItsUltraButton() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraInvite", "-uiTestTopics", "food"])
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists(within: 15))
        app.buttons["ideaCard.inspirationButton"].tap()
        let title = element(app, "inspiration.card.title")
        XCTAssertTrue(title.exists(within: 10))
        // The dock's own line stays under the sheet; the sheet has no card of its own.
        let sheet = element(app, "inspiration.sheet")
        XCTAssertFalse(sheet.descendants(matching: .any)["ultra.invite"].exists, "The invitation's card is back in Find inspiration")
        let ultra = app.buttons["inspiration.writeUltra"]
        XCTAssertTrue(ultra.exists(within: 5))
        XCTAssertTrue(ultra.label.contains("3 free"), "The Ultra AI action doesn't say the first scripts are free: \(ultra.label)")
        // The idea ends above "Start with it", whatever the invitation.
        let card = element(app, "inspiration.card")
        let use = app.buttons["inspiration.use"]
        XCTAssertTrue(card.exists)
        XCTAssertLessThanOrEqual(card.frame.maxY, use.frame.minY, "The idea runs under the actions")
        XCTAssertLessThanOrEqual(title.frame.maxY, use.frame.minY, "The idea's title is under the actions")
        ultra.tap()
        XCTAssertTrue(element(app, "ultra.consent").exists(within: 5), "Ultra AI was tried without asking")
    }

    /// With the free scripts used up, picking Ultra AI offers Cue Pro (its own calm Pro), and the chip stays on Apple
    /// Intelligence.
    func testWithNoFreeScriptsLeftUltraOffersCuePro() {
        let app = CueApp.launch(
            seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestUltraScriptsLeft", "0"]
        )
        pickUltra(app)
        XCTAssertTrue(text(app, containing: "Keep writing with Ultra AI.").exists(within: 5), "No Cue Pro when the free scripts are used up")
        XCTAssertTrue(text(app, containing: "Cue Pro adds 30 a month.").exists, "The Pro doesn't say how many scripts Cue Pro brings")
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

    /// "Delete my Cue data" takes Ultra AI's permission back (owner, 09/11/2026): the confirmation says what already left can't be called back,
    /// the switch is off afterwards, and picking Ultra AI again asks first.
    func testDeletingMyDataAsksForUltraAgain() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"])
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.exists(within: 15))
        settings.tap()
        let privacy = element(app, "settings.privacy")
        app.scroll(to: privacy)
        privacy.tap()
        let ultraSwitch = app.switches["privacy.ultra"]
        XCTAssertTrue(ultraSwitch.exists(within: 5))
        XCTAssertEqual(ultraSwitch.value as? String, "1")
        let delete = element(app, "settings.deleteData")
        app.scroll(to: delete)
        delete.tap()
        XCTAssertTrue(element(app, "actionSheet.note").exists(within: 5), "The confirmation doesn't say what can't be called back")
        XCTAssertTrue(text(app, containing: "within 30 days").exists && text(app, containing: "up to 2 years").exists)
        app.buttons["privacy.confirmDelete"].firstMatch.tap()
        app.scroll(to: ultraSwitch)
        XCTAssertTrue(ultraSwitch.matches(NSPredicate(format: "value == '0'"), within: 5), "Ultra AI is still allowed after deleting the data")
        app.cueTabBar.buttons["Scripts"].tap()
        pickUltra(app)
        XCTAssertTrue(element(app, "ultra.consent").exists(within: 5), "Ultra AI was picked without asking again")
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
    /// the permission sheet, the star, the written page with its reminder, Find inspiration's button and Settings.
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
        app.buttons["ultra.consent.allow"].tap()
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

    /// Settings › Privacy › Ultra AI · Lab opens on its counts, and gives the free scripts back (it was a black screen until 29/10/2026: the
    /// lab was made when an empty view appeared, which never happens).
    func testTheLabOpensAndGivesTheFreeScriptsBack() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestUltraScriptsLeft", "0"])
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.exists(within: 10))
        settings.tap()
        let privacy = element(app, "settings.privacy")
        app.scroll(to: privacy)
        privacy.tap()
        let lab = element(app, "privacy.ultraLab")
        app.scroll(to: lab)
        lab.tap()
        let giveBack = element(app, "ultraLab.resetAllowance")
        app.scroll(to: giveBack)
        XCTAssertTrue(app.staticTexts["Ultra AI · 0 of 3 free left"].exists(within: 5))
        giveBack.tap()
        XCTAssertTrue(app.staticTexts["Ultra AI · 3 of 3 free left"].exists(within: 5))
    }

    /// The lab says what a script cost (its two calls, in the usage each step reported) and adds it to what this iPhone spent. With
    /// `TEST_RUNNER_CUE_FIDELITY_DIR=<folder>` it keeps the pictures for `tools/contrast/audit.py`.
    func testTheLabSaysWhatAScriptCost() throws {
        let folder = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"].map { URL(fileURLWithPath: $0, isDirectory: true) }
        func shot(_ app: XCUIApplication, _ name: String) throws {
            guard let folder else { return }
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
            try app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
        }
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"])
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.exists(within: 10))
        settings.tap()
        let privacy = element(app, "settings.privacy")
        app.scroll(to: privacy)
        privacy.tap()
        let lab = element(app, "privacy.ultraLab")
        app.scroll(to: lab)
        lab.tap()
        let total = element(app, "ultraLab.spend.total")
        XCTAssertTrue(total.exists(within: 5))
        XCTAssertTrue(total.label.contains("0 calls"), "Nothing was spent yet: \(total.label)")
        try shot(app, "ultra_cost_01_lab")
        let prompt = element(app, "ultraLab.prompt")
        app.scroll(to: prompt)
        prompt.tap()
        prompt.typeText("Why I stopped buying bottled water")
        // A drag above the keyboard closes it (the lab's list does on a scroll); the scroll's own drag starts where the keyboard is.
        if app.keyboards.firstMatch.exists { app.swipeDown() }
        let generate = app.buttons["ultraLab.generate"]
        app.scroll(to: generate)
        generate.tap()
        // The result is lower down the list, which only builds the rows on screen.
        let runCost = element(app, "ultraLab.runCost")
        app.scroll(to: runCost)
        XCTAssertFalse(element(app, "ultraLab.failure").exists, "The lab's script failed")
        XCTAssertTrue(runCost.label.contains("2 calls"), "The script's cost: \(runCost.label)")
        try shot(app, "ultra_cost_02_run")
        for _ in 0..<12 where !total.isHittable { app.swipeDown() }
        XCTAssertTrue(total.label.contains("2 calls"), "This iPhone's total: \(total.label)")
        XCTAssertTrue(element(app, "ultraLab.spend.scripts").exists, "What a finished script costs is missing")
        try shot(app, "ultra_cost_03_total")
    }

    /// The pictures of the length bar past the ideal, Improve's header, the "A bit long" question and What Ultra AI
    /// sends, for `tools/contrast/audit.py` (`TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`).
    func testCaptureUltraFitAndPrivacyForTheContrastAudit() throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        func shot(_ app: XCUIApplication, _ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
            try app.debugDescription.write(to: folder.appending(path: "\(name).txt"), atomically: true, encoding: .utf8)
        }
        var app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestUltraLong"])
        pickUltra(app)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 5))
        field.tap()
        field.typeText("Why I stopped buying bottled water")
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(element(app, "page.lengthBar.past").exists(within: 25))
        try shot(app, "ultra_fit_01_length-bar")
        app.buttons["page.improveButton"].tap()
        XCTAssertTrue(app.buttons["improve.tool.fitToTime"].exists(within: 5))
        try shot(app, "ultra_fit_02_improve")
        app.swipeDown(velocity: .fast)
        XCTAssertTrue(app.buttons["detail.recordButton"].exists(within: 5))
        app.buttons["detail.recordButton"].tap()
        XCTAssertTrue(app.buttons["page.nudge.shorter"].exists(within: 5))
        try shot(app, "ultra_fit_03_nudge")
        app.terminate()
        app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"])
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.exists(within: 10))
        settings.tap()
        let privacy = element(app, "settings.privacy")
        app.scroll(to: privacy)
        privacy.tap()
        let detail = element(app, "privacy.ultraDetail")
        app.scroll(to: detail)
        try shot(app, "ultra_fit_04_privacy")
        detail.tap()
        XCTAssertTrue(element(app, "privacy.ultraDetail.screen").exists(within: 5))
        try shot(app, "ultra_fit_05_sends-top")
        let training = text(app, containing: "doesn’t use it to train")
        app.scroll(to: training)
        try shot(app, "ultra_fit_06_sends-middle")
        let requests = element(app, "privacy.ultraRequests")
        app.scroll(to: requests)
        try shot(app, "ultra_fit_07_sends-bottom")
        requests.tap()
        XCTAssertTrue(element(app, "ultra.payload.draft").exists(within: 5))
        try shot(app, "ultra_fit_08_requests")
    }

    /// Ultra AI's scene round the star, in pictures through a whole run (`TEST_RUNNER_CUE_FIDELITY_DIR=<folder>`): the stub paced as Gemini's
    /// go with a long check (`-uiTestUltraPacedLong`: 22 s of thinking with no words, when the galaxy must keep turning, and a comet), real
    /// animations, a picture every 1.2 s until the page is there; the words under the scene for `tools/contrast/audit.py`.
    func testCaptureTheUltraWaitScene() throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_FIDELITY_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_FIDELITY_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let app = CueApp.launch(
            seeded: true, animations: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestStarTransition", "-uiTestUltraPacedLong"]
        )
        pickUltra(app)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 5))
        field.tap()
        field.typeText("Why I stopped buying bottled water")
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(text(app, containing: "Drafting with Ultra AI").exists(within: 5))
        try app.debugDescription.write(to: folder.appending(path: "ultra_wait.txt"), atomically: true, encoding: .utf8)
        let started = Date()
        var shot = 0
        while Date().timeIntervalSince(started) < 60, !element(app, "page.editor").exists {
            try app.screenshot().pngRepresentation.write(to: folder.appending(path: String(format: "ultra_wait_%02d.png", shot)))
            shot += 1
            Thread.sleep(forTimeInterval: 1.2)
        }
        XCTAssertTrue(element(app, "page.editor").exists(within: 10), "No page after the scene")
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
        XCTAssertTrue(app.buttons["inspiration.writeUltra"].matches(NSPredicate(format: "label CONTAINS %@", "3 free"), within: 5))
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
