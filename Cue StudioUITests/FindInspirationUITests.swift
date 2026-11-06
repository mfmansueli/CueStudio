//
//  FindInspirationUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Find inspiration and the empty Scripts: the three ways in on a first use and their lighter returning state, the dock's lightbulb once there
/// are scripts, the topic filters (several topics, only typed ones, none), "Another idea", "Start with it" into the composer with Undo, the
/// direct "Draft it now", and the screen at the biggest text sizes. With `TEST_RUNNER_CUE_INSPIRATION_DIR=<folder>` each test keeps
/// pictures (attachments), also written there with their accessibility hierarchies, for `tools/contrast/audit.py`.
@MainActor
final class FindInspirationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - The empty Scripts

    /// Two cards (Write it yourself, Import a script) and the dock's lightbulb, which is in every state of Scripts (10/10/2026).
    func testTheFirstUseOffersItsWaysInAndTheListTakesItsPlaceAfterTheFirstScript() throws {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(element(app, "empty.firstUse").exists(within: 15))
        XCTAssertEqual(element(app, "empty.title").label, "How do you want to start?")
        for id in ["empty.writeButton", "empty.importButton"] {
            XCTAssertTrue(app.buttons[id].exists, "No \(id)")
        }
        XCTAssertFalse(app.buttons["empty.inspirationButton"].exists, "Find inspiration is the dock's lightbulb, not a card")
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists, "The lightbulb is in the dock from the first visit")
        XCTAssertTrue(app.buttons["ideaCard.submit"].exists, "The dock stays the place to type an idea")
        XCTAssertTrue(element(app, "empty.promptCard").exists, "No dock on the empty Scripts")
        // The Logbook is in the bar and Format on the card from the first visit on, not only after the first script.
        XCTAssertTrue(app.buttons["scripts.logbookButton"].exists, "No Logbook on the empty Scripts")
        XCTAssertTrue(app.buttons["ideaCard.formatChip"].exists, "No Format on the empty Scripts' card")
        try shoot(app, "01-first-use")

        writeFirstScript(app, titled: "My first script")
        XCTAssertFalse(element(app, "empty.firstUse").exists)
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists(within: 5), "The lightbulb stays with scripts")
    }

    func testDeletingEveryScriptShowsTheReturningStateNotTheFirstUse() throws {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(element(app, "empty.firstUse").exists(within: 15))
        writeFirstScript(app, titled: "Short lived")
        app.scriptRow("Short lived").press(forDuration: 1.2)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.exists(within: 5))
        delete.tap()

        XCTAssertTrue(element(app, "empty.returning").exists(within: 10), "An emptied library went back to the first use")
        XCTAssertFalse(element(app, "empty.firstUse").exists)
        XCTAssertEqual(element(app, "empty.title").label, "Ready for the next one?")
        for id in ["empty.writeButton", "empty.importButton", "ideaCard.inspirationButton"] {
            XCTAssertTrue(app.buttons[id].exists, "No \(id) in the returning state")
        }
        if capturing { sleep(5) } // The Undo toast goes before the picture.
        try shoot(app, "05-returning")
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.sheet").exists(within: 5))
    }

    // MARK: - The lightbulb and the sheet

    func testTheLightbulbOpensFindInspirationWithEveryTopicAsAFilter() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "finance,food,custom:Daily Routine"])
        let bulb = app.buttons["ideaCard.inspirationButton"]
        XCTAssertTrue(bulb.exists(within: 15))
        XCTAssertTrue(bulb.isHittable)
        XCTAssertEqual(bulb.label, "Find inspiration")
        // 44 pt, give or take the layout's rounding (43.99999…).
        XCTAssertGreaterThanOrEqual(bulb.frame.width, 44 - 0.01)
        // Right after the voice chip, on the same row.
        let voice = app.buttons["ideaCard.voiceChip"]
        XCTAssertGreaterThan(bulb.frame.minX, voice.frame.minX)
        XCTAssertEqual(bulb.frame.midY, voice.frame.midY, accuracy: 6)
        try shoot(app, "02-scripts-lightbulb")

        bulb.tap()
        XCTAssertTrue(element(app, "inspiration.sheet").exists(within: 5))
        // The row is folded into the chosen chip, as in Scripts and Takes (`FilterFan`); "Topics" is always in sight.
        XCTAssertTrue(app.buttons["inspiration.filter.all"].isSelected)
        XCTAssertFalse(app.buttons["inspiration.filter.food"].exists, "Folded, only the chosen chip is there")
        XCTAssertTrue(app.buttons["inspiration.editTopics"].isHittable)
        app.buttons["inspiration.filter.all"].tap()
        for id in ["all", "finance", "food", "custom.daily-routine"] {
            XCTAssertTrue(app.buttons["inspiration.filter.\(id)"].exists(within: 3), "No filter \(id)")
        }
        app.buttons["inspiration.filter.all"].tap()
        XCTAssertTrue(app.buttons["inspiration.filter.food"].isGone(within: 3), "A tap on the chosen chip folds the row")
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        XCTAssertTrue(app.buttons["inspiration.use"].isHittable)
        XCTAssertTrue(app.buttons["inspiration.another"].isHittable)
        try shoot(app, "03-sheet")

        pickFilter(app, "food")
        XCTAssertTrue(app.buttons["inspiration.filter.food"].isSelected)
        XCTAssertTrue(app.buttons["inspiration.filter.all"].isGone(within: 3), "A pick folds the row into it")
        XCTAssertTrue(element(app, "inspiration.card.category").exists(within: 5))
        XCTAssertTrue(element(app, "inspiration.card.category").label.localizedCaseInsensitiveContains("Food"))

        // A topic the creator typed has no starters: the model's ideas (the stub's) come, after a short wait at most.
        pickFilter(app, "custom.daily-routine")
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10) || element(app, "inspiration.loading").exists)
    }

    func testAnotherIdeaShowsTheNextCard() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "fitness"])
        openSheet(app)
        let title = element(app, "inspiration.card.title")
        XCTAssertTrue(title.exists(within: 10))
        let first = title.label
        // The button is beside "Start with it", at the bottom: it stays where it is whatever the size of the idea above it.
        let place = app.buttons["inspiration.another"].frame
        app.buttons["inspiration.another"].tap()
        let changed = NSPredicate { _, _ in title.exists && title.label != first }
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: changed, evaluatedWith: nil)], timeout: 5), .completed, "The card stayed \(first)")
        XCTAssertEqual(app.buttons["inspiration.another"].frame, place, "Another idea moved with the idea")
        XCTAssertEqual(app.buttons["inspiration.another"].frame.midY, app.buttons["inspiration.use"].frame.midY, accuracy: 1)
        // A swipe on the card is "Another idea" too.
        let second = title.label
        element(app, "inspiration.card").swipeLeft()
        let swiped = NSPredicate { _, _ in title.exists && title.label != second }
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: swiped, evaluatedWith: nil)], timeout: 5), .completed)
    }

    func testUseThisIdeaFillsTheComposerKeepsTheDraftWithUndoAndCanBeEdited() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "finance"])
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 15))
        field.tap()
        field.typeText("my own words")
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.sheet").exists(within: 5))
        let title = element(app, "inspiration.card.title")
        XCTAssertTrue(title.exists(within: 10))
        let hasBrief = element(app, "inspiration.card.opening").exists
        let ideaTitle = title.label
        app.buttons["inspiration.use"].tap()

        let undo = app.buttons["toast.action"]
        XCTAssertTrue(undo.exists(within: 5), "The creator's words were replaced without an Undo")
        XCTAssertFalse(element(app, "inspiration.sheet").exists)
        let used = field.value as? String ?? ""
        // The brief (subject, angle and "Open with: …") when the idea has one, its title otherwise.
        XCTAssertTrue(hasBrief ? used.contains("Open with") : used.contains(ideaTitle), "The composer says \(used)")
        XCTAssertFalse(used.contains("my own words"))
        undo.tap()
        XCTAssertEqual(field.value as? String, "my own words")

        // Again, and this time it stays: the composer shows the idea, ready to change.
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(app.buttons["inspiration.use"].exists(within: 5))
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        app.buttons["inspiration.use"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.exists(within: 5), "The composer takes the keyboard to adapt the idea")
        if capturing { sleep(5) } // The Undo toast goes before the picture.
        try shoot(app, "04-composer-after-use")
        let before = field.value as? String ?? ""
        field.typeText(" for students")
        XCTAssertEqual(field.value as? String, before + " for students")
        XCTAssertTrue(app.buttons["ideaCard.submit"].isEnabled)
    }

    /// An idea from Find inspiration not yet changed keeps the dock's ↻: it passes the idea for the next suggestion (owner, 05/11/2026).
    func testTheDocksAnotherIdeaPassesAnUntouchedInspiration() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "finance"])
        openSheet(app)
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        app.buttons["inspiration.use"].tap()
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 5))
        XCTAssertFalse((field.value as? String ?? "").isEmpty)
        let another = app.buttons["ideaCard.anotherIdea"]
        XCTAssertTrue(another.exists(within: 5), "The idea from Find inspiration took the dock's ↻ away")
        another.tap()
        XCTAssertTrue(app.buttons["ideaCard.anotherIdea"].exists(within: 5), "The next suggestion has its ↻")
        // Typed words are the creator's: no ↻.
        field.tap()
        field.typeText("mine")
        XCTAssertTrue(app.buttons["ideaCard.anotherIdea"].isGone(within: 3))
    }

    func testWriteTheScriptNowWritesTheIdeaAsItIsAndLeavesTheComposer() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "food"])
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 15))
        field.tap()
        field.typeText("keep me")
        app.buttons["ideaCard.inspirationButton"].tap()
        let write = app.buttons["inspiration.writeNow"]
        XCTAssertTrue(write.exists(within: 5))
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        write.tap()
        XCTAssertTrue(element(app, "page.editor").exists(within: 15), "No page written from the idea")
        app.pageBackButton.tap()
        XCTAssertEqual(element(app, "ideaCard.field").value as? String, "keep me", "Writing now touched the composer's draft")
    }

    // MARK: - Topics: none, only typed ones, no Apple Intelligence

    func testWithoutTopicsTheSheetStillSuggestsAndOffersToAddThem() {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists(within: 15))
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10), "No general ideas without topics")
        // One line at most above the card: "+ Add topics" says what to do (the owner, 05/11/2026).
        XCTAssertFalse(element(app, "inspiration.noTopicsNote").exists)
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inspiration.filter.'")).count, 1)
        let add = app.buttons["inspiration.editTopics"]
        XCTAssertTrue(add.exists)
        add.tap()
        XCTAssertTrue(element(app, "voice.editor.topics").exists(within: 5), "Add topics didn't open the topics")
    }

    func testOnlyTypedTopicsWithoutAppleIntelligenceGetStartersAboutThemSaidToBeStarters() {
        let app = CueApp.launch(seeded: true, ai: .none, extraArguments: ["-uiTestTopics", "custom:Daily Routine"])
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists(within: 15), "The lightbulb is there without Apple Intelligence too")
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.startersNote").exists(within: 5))
        pickFilter(app, "custom.daily-routine")
        let category = element(app, "inspiration.card.category")
        XCTAssertTrue(category.exists(within: 5))
        XCTAssertTrue(category.label.localizedCaseInsensitiveContains("Daily Routine"), category.label)
        XCTAssertTrue(app.buttons["inspiration.use"].isEnabled)
        XCTAssertEqual(app.buttons["inspiration.writeNow"].label, "Write it yourself")
    }

    /// Near a day people plan videos around, the first idea is tied to it, and the card says why ("Coming up: Mother’s Day").
    func testAnIdeaTiedToADayComingUpSaysWhyOnTheCard() throws {
        let app = CueApp.launch(
            seeded: true, ai: .none, extraArguments: ["-uiTestTopics", "custom:Daily Routine", "-uiTestOccasions", "BR@2026-04-25"]
        )
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists(within: 15))
        app.buttons["ideaCard.inspirationButton"].tap()
        let why = element(app, "inspiration.card.why")
        XCTAssertTrue(why.exists(within: 5), "The tied idea doesn't say why")
        XCTAssertTrue(why.label.contains("Mother"), why.label)
        try shoot(app, "11-why-line")
    }

    func testWhenTheIdeasDontComeTheSheetSaysSoAndOffersTryAgain() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "custom:Daily Routine", "-uiTestIdeasFail"])
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists(within: 15))
        app.buttons["ideaCard.inspirationButton"].tap()
        pickFilter(app, "custom.daily-routine")
        // Through the starters about the topic (16 templates and the ties to posted videos), to where only the model's ideas could come: they
        // fail, and the sheet says so.
        let failed = element(app, "inspiration.failed")
        let note = element(app, "inspiration.couldNotFindMore")
        for _ in 0..<30 where !failed.exists && !note.exists {
            let another = app.buttons["inspiration.another"]
            if another.isEnabled { another.tap() } else { sleep(1) }
        }
        XCTAssertTrue(failed.exists(within: 10) || note.exists, "A failure looked like nothing happened")
        try shoot(app, "10-ideas-failed")
        let retry = failed.exists ? app.buttons["inspiration.retry"] : app.buttons["inspiration.retryMore"]
        XCTAssertTrue(retry.exists)
        retry.tap()
    }

    func testWhileTheNextIdeasAreOnTheirWayTheCardStaysAndSaysSo() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "custom:Daily Routine", "-uiTestIdeasSlow"])
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists(within: 15))
        app.buttons["ideaCard.inspirationButton"].tap()
        pickFilter(app, "custom.daily-routine")
        let title = element(app, "inspiration.card.title")
        // The first six take 12 s and the next 48 s (`-uiTestIdeasSlow`): past the starters (16 templates and the ties to posted videos) and the
        // first six, the end of what is ready is always reached.
        XCTAssertTrue(title.exists(within: 30), "The first ideas never came")
        let first = title.label
        // Tapping on reaches the end of what is ready: the button waits ("Finding more ideas…") and the card stays.
        let another = app.buttons["inspiration.another"]
        var sawWait = false
        for _ in 0..<40 {
            if !another.isEnabled || another.label.contains("Finding") { sawWait = true; break }
            another.tap()
        }
        XCTAssertTrue(sawWait, "The wait for the next ideas was never shown")
        XCTAssertTrue(title.exists, "The card went while the next ideas were on their way")
        try shoot(app, "11-finding-more")
        XCTAssertTrue(another.matches(NSPredicate(format: "enabled == true AND NOT (label CONTAINS 'Finding')"), within: 60), "The next ideas never came")
        another.tap()
        XCTAssertNotEqual(title.label, first)
    }

    func testWithoutAppleIntelligenceTheDirectWayIsWritingItYourself() {
        let app = CueApp.launch(seeded: false, ai: .none, extraArguments: ["-uiTestTopics", "travel"])
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].exists(within: 15))
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.startersNote").exists(within: 5))
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 5))
        let write = app.buttons["inspiration.writeNow"]
        XCTAssertEqual(write.label, "Write it yourself")
        write.tap()
        XCTAssertTrue(app.textFields["page.titleField"].exists(within: 10), "No blank draft")
    }

    // MARK: - The card with a whole brief

    /// The stub writer's ideas have no brief yet: the design catalogue shows the card with one (`-uiTestCatalogue inspire`).
    func testTheCardReadsAsOneBriefTitleAngleAndOpeningLine() throws {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestCatalogue", "inspire"])
        let card = element(app, "catalogue.inspire.brief")
        XCTAssertTrue(card.exists(within: 15))
        XCTAssertTrue(card.staticTexts["Why saving feels harder than spending"].exists)
        let angle = card.descendants(matching: .any)["inspiration.card.angle"].firstMatch
        let opening = card.descendants(matching: .any)["inspiration.card.opening"].firstMatch
        XCTAssertTrue(angle.label.contains("Explain one small habit"), angle.label)
        XCTAssertTrue(opening.label.contains("what you make automatic"), opening.label)
        XCTAssertLessThan(angle.frame.minY, opening.frame.minY, "The angle comes before the opening line")
        try shoot(app, "09-card-with-brief")
    }

    // MARK: - Big text

    func testAtTheBiggestTextSizesEverythingIsStillReachable() throws {
        let app = CueApp.launch(
            seeded: true, contentSize: "UICTContentSizeCategoryAccessibilityXL", extraArguments: ["-uiTestTopics", "finance,custom:Daily Routine"]
        )
        let bulb = app.buttons["ideaCard.inspirationButton"]
        XCTAssertTrue(bulb.exists(within: 15))
        XCTAssertTrue(bulb.isHittable, "The lightbulb was pushed out of the dock")
        try shoot(app, "06-scripts-large-text")
        bulb.tap()
        XCTAssertTrue(element(app, "inspiration.card.title").exists(within: 10))
        try shoot(app, "07-sheet-large-text")
        let use = app.buttons["inspiration.use"]
        app.scroll(to: use, in: element(app, "inspiration.sheet"))
        XCTAssertTrue(use.isHittable)
        use.tap()
        XCTAssertFalse(element(app, "inspiration.sheet").exists(within: 2))
    }

    func testTheFirstUseAtTheBiggestTextSizesScrollsToEveryWayIn() throws {
        let app = CueApp.launch(seeded: false, contentSize: "UICTContentSizeCategoryAccessibilityXL")
        XCTAssertTrue(element(app, "empty.firstUse").exists(within: 15))
        try shoot(app, "08-first-use-large-text")
        let importButton = app.buttons["empty.importButton"]
        app.scroll(to: importButton)
        XCTAssertTrue(importButton.isHittable)
    }

    // MARK: - Helpers

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// Picks a topic in the folded row: a tap on the chosen chip opens it, a tap on the topic picks it and folds it.
    private func pickFilter(_ app: XCUIApplication, _ id: String) {
        let chip = app.buttons["inspiration.filter.\(id)"]
        if !chip.exists {
            app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inspiration.filter.' AND selected == true")).firstMatch.tap()
        }
        XCTAssertTrue(chip.exists(within: 3), "No filter \(id)")
        chip.waitUntilStill()
        // The open row scrolls sideways, as in Scripts: a topic past the screen's edge comes into reach.
        // (Past "Topics" a chip is under its fade: by its frame, since asking whether it can be hit throws there.)
        let reach = app.buttons["inspiration.editTopics"].frame.minX
        for _ in 0..<4 where chip.frame.maxX > reach {
            element(app, "inspiration.filters").swipeLeft()
            chip.waitUntilStill()
        }
        chip.tap()
    }

    private func openSheet(_ app: XCUIApplication) {
        let bulb = app.buttons["ideaCard.inspirationButton"]
        XCTAssertTrue(bulb.exists(within: 15))
        bulb.tap()
        XCTAssertTrue(element(app, "inspiration.sheet").exists(within: 5))
    }

    /// "Write it yourself", a title, back: the library has its first script.
    private func writeFirstScript(_ app: XCUIApplication, titled title: String) {
        app.buttons["empty.writeButton"].tap()
        let field = app.textFields["page.titleField"]
        XCTAssertTrue(field.exists(within: 5))
        XCTAssertTrue(app.keyboards.firstMatch.exists(within: 10))
        field.typeText(title)
        app.pageBackButton.tap()
        XCTAssertTrue(app.staticTexts[title].exists(within: 5))
    }

    /// Pictures are taken only when `TEST_RUNNER_CUE_INSPIRATION_DIR` is set: the waits they need stay out of the normal runs.
    private var capturing: Bool { ProcessInfo.processInfo.environment["CUE_INSPIRATION_DIR"] != nil }

    /// A picture of the screen, kept with the result and in `TEST_RUNNER_CUE_INSPIRATION_DIR` with its hierarchy; nothing when it isn't set.
    private func shoot(_ app: XCUIApplication, _ name: String) throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_INSPIRATION_DIR"] else { return }
        sleep(1)
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"].map { "-" + $0.replacingOccurrences(of: " ", with: "_") } ?? ""
        try screenshot.pngRepresentation.write(to: folder.appending(path: "\(name)\(device).png"))
        try app.debugDescription.write(to: folder.appending(path: "\(name)\(device).txt"), atomically: true, encoding: .utf8)
    }
}
