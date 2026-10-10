//
//  FindInspirationUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Find inspiration and the empty Scripts: the three ways in on a first use and their lighter returning state, the dock's lightbulb once there
/// are scripts, the topic filters (several topics, only typed ones, none), "Another idea", "Use this idea" into the composer with Undo, the
/// direct "Write the script now", and the screen at the biggest text sizes. Each test keeps a picture (an attachment); with
/// `TEST_RUNNER_CUE_INSPIRATION_DIR=<folder>` the pictures and their accessibility hierarchies are also written there, for
/// `tools/contrast/audit.py`.
@MainActor
final class FindInspirationUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    // MARK: - The empty Scripts

    func testTheFirstUseOffersThreeWaysInAndTheListTakesItsPlaceAfterTheFirstScript() throws {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(element(app, "empty.firstUse").waitForExistence(timeout: 15))
        XCTAssertEqual(element(app, "empty.title").label, "How do you want to start?")
        for id in ["empty.inspirationButton", "empty.writeButton", "empty.importButton"] {
            XCTAssertTrue(app.buttons[id].exists, "No \(id)")
        }
        XCTAssertTrue(app.buttons["empty.inspirationButton"].label.contains("Find inspiration"))
        XCTAssertFalse(app.buttons["ideaCard.inspirationButton"].exists, "The empty Scripts has its own way in: no lightbulb in the dock")
        XCTAssertTrue(app.buttons["ideaCard.submit"].exists, "The dock stays the place to type an idea")
        try shoot(app, "01-first-use")

        writeFirstScript(app, titled: "My first script")
        XCTAssertFalse(element(app, "empty.firstUse").exists)
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].waitForExistence(timeout: 5), "No lightbulb once there are scripts")
    }

    func testDeletingEveryScriptShowsTheReturningStateNotTheFirstUse() throws {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(element(app, "empty.firstUse").waitForExistence(timeout: 15))
        writeFirstScript(app, titled: "Short lived")
        app.scriptRow("Short lived").press(forDuration: 1.2)
        let delete = app.buttons["Delete"]
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        XCTAssertTrue(element(app, "empty.returning").waitForExistence(timeout: 10), "An emptied library went back to the first use")
        XCTAssertFalse(element(app, "empty.firstUse").exists)
        XCTAssertEqual(element(app, "empty.title").label, "Ready for the next one?")
        for id in ["empty.inspirationButton", "empty.writeButton", "empty.importButton"] {
            XCTAssertTrue(app.buttons[id].exists, "No \(id) in the returning state")
        }
        sleep(5) // The Undo toast goes before the picture.
        try shoot(app, "05-returning")
        app.buttons["empty.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.sheet").waitForExistence(timeout: 5))
    }

    // MARK: - The lightbulb and the sheet

    func testTheLightbulbOpensFindInspirationWithEveryTopicAsAFilter() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "finance,food,custom:Daily Routine"])
        let bulb = app.buttons["ideaCard.inspirationButton"]
        XCTAssertTrue(bulb.waitForExistence(timeout: 15))
        XCTAssertTrue(bulb.isHittable)
        XCTAssertEqual(bulb.label, "Find inspiration")
        XCTAssertGreaterThanOrEqual(bulb.frame.width, 44)
        // Right after the voice chip, on the same row.
        let voice = app.buttons["ideaCard.voiceChip"]
        XCTAssertGreaterThan(bulb.frame.minX, voice.frame.minX)
        XCTAssertEqual(bulb.frame.midY, voice.frame.midY, accuracy: 6)
        try shoot(app, "02-scripts-lightbulb")

        bulb.tap()
        XCTAssertTrue(element(app, "inspiration.sheet").waitForExistence(timeout: 5))
        for id in ["all", "finance", "food", "custom.daily-routine"] {
            XCTAssertTrue(app.buttons["inspiration.filter.\(id)"].exists, "No filter \(id)")
        }
        XCTAssertTrue(app.buttons["inspiration.filter.all"].isSelected)
        XCTAssertTrue(element(app, "inspiration.card.title").waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["inspiration.use"].isHittable)
        XCTAssertTrue(app.buttons["inspiration.another"].isHittable)
        try shoot(app, "03-sheet")

        app.buttons["inspiration.filter.food"].tap()
        XCTAssertTrue(app.buttons["inspiration.filter.food"].isSelected)
        XCTAssertFalse(app.buttons["inspiration.filter.all"].isSelected)
        XCTAssertTrue(element(app, "inspiration.card.category").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "inspiration.card.category").label.localizedCaseInsensitiveContains("Food"))

        // A topic the creator typed has no starters: the model's ideas (the stub's) come, after a short wait at most.
        app.buttons["inspiration.filter.custom.daily-routine"].tap()
        XCTAssertTrue(element(app, "inspiration.card.title").waitForExistence(timeout: 10) || element(app, "inspiration.loading").exists)
    }

    func testAnotherIdeaShowsTheNextCard() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "fitness"])
        openSheet(app)
        let title = element(app, "inspiration.card.title")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let first = title.label
        app.buttons["inspiration.another"].tap()
        let changed = NSPredicate { _, _ in title.exists && title.label != first }
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: changed, evaluatedWith: nil)], timeout: 5), .completed, "The card stayed \(first)")
        // A swipe on the card is "Another idea" too.
        let second = title.label
        element(app, "inspiration.card").swipeLeft()
        let swiped = NSPredicate { _, _ in title.exists && title.label != second }
        XCTAssertEqual(XCTWaiter().wait(for: [expectation(for: swiped, evaluatedWith: nil)], timeout: 5), .completed)
    }

    func testUseThisIdeaFillsTheComposerKeepsTheDraftWithUndoAndCanBeEdited() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "finance"])
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("my own words")
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.sheet").waitForExistence(timeout: 5))
        let title = element(app, "inspiration.card.title")
        XCTAssertTrue(title.waitForExistence(timeout: 10))
        let hasBrief = element(app, "inspiration.card.opening").exists
        let ideaTitle = title.label
        app.buttons["inspiration.use"].tap()

        let undo = app.buttons["toast.action"]
        XCTAssertTrue(undo.waitForExistence(timeout: 5), "The creator's words were replaced without an Undo")
        XCTAssertFalse(element(app, "inspiration.sheet").exists)
        let used = field.value as? String ?? ""
        // The brief (subject, angle and "Open with: …") when the idea has one, its title otherwise.
        XCTAssertTrue(hasBrief ? used.contains("Open with") : used.contains(ideaTitle), "The composer says \(used)")
        XCTAssertFalse(used.contains("my own words"))
        undo.tap()
        XCTAssertEqual(field.value as? String, "my own words")

        // Again, and this time it stays: the composer shows the idea, ready to change.
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(app.buttons["inspiration.use"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "inspiration.card.title").waitForExistence(timeout: 10))
        app.buttons["inspiration.use"].tap()
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 5), "The composer takes the keyboard to adapt the idea")
        sleep(5) // The Undo toast goes before the picture.
        try shoot(app, "04-composer-after-use")
        let before = field.value as? String ?? ""
        field.typeText(" for students")
        XCTAssertEqual(field.value as? String, before + " for students")
        XCTAssertTrue(app.buttons["ideaCard.submit"].isEnabled)
    }

    func testWriteTheScriptNowWritesTheIdeaAsItIsAndLeavesTheComposer() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "food"])
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("keep me")
        app.buttons["ideaCard.inspirationButton"].tap()
        let write = app.buttons["inspiration.writeNow"]
        XCTAssertTrue(write.waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "inspiration.card.title").waitForExistence(timeout: 10))
        write.tap()
        XCTAssertTrue(element(app, "page.editor").waitForExistence(timeout: 15), "No page written from the idea")
        app.pageBackButton.tap()
        XCTAssertEqual(element(app, "ideaCard.field").value as? String, "keep me", "Writing now touched the composer's draft")
    }

    // MARK: - Topics: none, only typed ones, no Apple Intelligence

    func testWithoutTopicsTheSheetStillSuggestsAndOffersToAddThem() {
        let app = CueApp.launch(seeded: false)
        XCTAssertTrue(app.buttons["empty.inspirationButton"].waitForExistence(timeout: 15))
        app.buttons["empty.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.noTopicsNote").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "inspiration.card.title").waitForExistence(timeout: 10), "No general ideas without topics")
        XCTAssertEqual(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'inspiration.filter.'")).count, 1)
        let add = app.buttons["inspiration.editTopics"]
        XCTAssertTrue(add.exists)
        add.tap()
        XCTAssertTrue(element(app, "voice.editor.topics").waitForExistence(timeout: 5), "Add topics didn't open the topics")
    }

    func testOnlyTypedTopicsWithoutAppleIntelligenceGetStartersAboutThemSaidToBeStarters() {
        let app = CueApp.launch(seeded: true, ai: .none, extraArguments: ["-uiTestTopics", "custom:Daily Routine"])
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].waitForExistence(timeout: 15), "The lightbulb is there without Apple Intelligence too")
        app.buttons["ideaCard.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.startersNote").waitForExistence(timeout: 5))
        app.buttons["inspiration.filter.custom.daily-routine"].tap()
        let category = element(app, "inspiration.card.category")
        XCTAssertTrue(category.waitForExistence(timeout: 5))
        XCTAssertTrue(category.label.localizedCaseInsensitiveContains("Daily Routine"), category.label)
        XCTAssertTrue(app.buttons["inspiration.use"].isEnabled)
        XCTAssertEqual(app.buttons["inspiration.writeNow"].label, "Write it yourself")
    }

    func testWhenTheIdeasDontComeTheSheetSaysSoAndOffersTryAgain() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "custom:Daily Routine", "-uiTestIdeasFail"])
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].waitForExistence(timeout: 15))
        app.buttons["ideaCard.inspirationButton"].tap()
        app.buttons["inspiration.filter.custom.daily-routine"].tap()
        // Through the starters about the topic, to where only the model's ideas could come: they fail, and the sheet says so.
        let failed = element(app, "inspiration.failed")
        let note = element(app, "inspiration.couldNotFindMore")
        for _ in 0..<12 where !failed.exists && !note.exists {
            let another = app.buttons["inspiration.another"]
            if another.isEnabled { another.tap() } else { sleep(1) }
        }
        XCTAssertTrue(failed.waitForExistence(timeout: 10) || note.exists, "A failure looked like nothing happened")
        try shoot(app, "10-ideas-failed")
        let retry = failed.exists ? app.buttons["inspiration.retry"] : app.buttons["inspiration.retryMore"]
        XCTAssertTrue(retry.exists)
        retry.tap()
    }

    func testWhileTheNextIdeasAreOnTheirWayTheCardStaysAndSaysSo() throws {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestTopics", "custom:Daily Routine", "-uiTestIdeasSlow"])
        XCTAssertTrue(app.buttons["ideaCard.inspirationButton"].waitForExistence(timeout: 15))
        app.buttons["ideaCard.inspirationButton"].tap()
        app.buttons["inspiration.filter.custom.daily-routine"].tap()
        let title = element(app, "inspiration.card.title")
        let loading = element(app, "inspiration.loading")
        XCTAssertTrue(title.waitForExistence(timeout: 10) || loading.exists, "Neither a card nor the wait")
        // Tapping on quickly reaches the end of what is ready: the button waits ("Finding more ideas…") and the card stays.
        var sawWait = loading.exists
        for _ in 0..<12 where !sawWait {
            let another = app.buttons["inspiration.another"]
            if !another.isEnabled || another.label.contains("Finding") { sawWait = true; break }
            another.tap()
        }
        XCTAssertTrue(sawWait || loading.exists, "The wait for the next ideas was never shown")
        try shoot(app, "11-finding-more")
        XCTAssertTrue(title.waitForExistence(timeout: 15), "The next idea never came")
    }

    func testWithoutAppleIntelligenceTheDirectWayIsWritingItYourself() {
        let app = CueApp.launch(seeded: false, ai: .none, extraArguments: ["-uiTestTopics", "travel"])
        XCTAssertTrue(app.buttons["empty.inspirationButton"].waitForExistence(timeout: 15))
        app.buttons["empty.inspirationButton"].tap()
        XCTAssertTrue(element(app, "inspiration.startersNote").waitForExistence(timeout: 5))
        XCTAssertTrue(element(app, "inspiration.card.title").waitForExistence(timeout: 5))
        let write = app.buttons["inspiration.writeNow"]
        XCTAssertEqual(write.label, "Write it yourself")
        write.tap()
        XCTAssertTrue(app.textFields["page.titleField"].waitForExistence(timeout: 10), "No blank draft")
    }

    // MARK: - The card with a whole brief

    /// The stub writer's ideas have no brief yet: the design catalogue shows the card with one (`-uiTestCatalogue inspire`).
    func testTheCardReadsAsOneBriefTitleAngleAndOpeningLine() throws {
        let app = CueApp.launch(seeded: false, extraArguments: ["-uiTestCatalogue", "inspire"])
        let card = element(app, "catalogue.inspire.brief")
        XCTAssertTrue(card.waitForExistence(timeout: 15))
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
        XCTAssertTrue(bulb.waitForExistence(timeout: 15))
        XCTAssertTrue(bulb.isHittable, "The lightbulb was pushed out of the dock")
        try shoot(app, "06-scripts-large-text")
        bulb.tap()
        XCTAssertTrue(element(app, "inspiration.card.title").waitForExistence(timeout: 10))
        try shoot(app, "07-sheet-large-text")
        let use = app.buttons["inspiration.use"]
        app.scroll(to: use, in: element(app, "inspiration.sheet"))
        XCTAssertTrue(use.isHittable)
        use.tap()
        XCTAssertFalse(element(app, "inspiration.sheet").waitForExistence(timeout: 2))
    }

    func testTheFirstUseAtTheBiggestTextSizesScrollsToEveryWayIn() throws {
        let app = CueApp.launch(seeded: false, contentSize: "UICTContentSizeCategoryAccessibilityXL")
        XCTAssertTrue(element(app, "empty.firstUse").waitForExistence(timeout: 15))
        try shoot(app, "08-first-use-large-text")
        let importButton = app.buttons["empty.importButton"]
        app.scroll(to: importButton)
        XCTAssertTrue(importButton.isHittable)
    }

    // MARK: - Helpers

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    private func openSheet(_ app: XCUIApplication) {
        let bulb = app.buttons["ideaCard.inspirationButton"]
        XCTAssertTrue(bulb.waitForExistence(timeout: 15))
        bulb.tap()
        XCTAssertTrue(element(app, "inspiration.sheet").waitForExistence(timeout: 5))
    }

    /// "Write it yourself", a title, back: the library has its first script.
    private func writeFirstScript(_ app: XCUIApplication, titled title: String) {
        app.buttons["empty.writeButton"].tap()
        let field = app.textFields["page.titleField"]
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        XCTAssertTrue(app.keyboards.firstMatch.waitForExistence(timeout: 10))
        field.typeText(title)
        app.pageBackButton.tap()
        XCTAssertTrue(app.staticTexts[title].waitForExistence(timeout: 5))
    }

    /// A picture of the screen, kept with the result, and in `TEST_RUNNER_CUE_INSPIRATION_DIR` with its hierarchy when that is set.
    private func shoot(_ app: XCUIApplication, _ name: String) throws {
        sleep(1)
        let screenshot = app.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        guard let path = ProcessInfo.processInfo.environment["CUE_INSPIRATION_DIR"] else { return }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let device = ProcessInfo.processInfo.environment["SIMULATOR_DEVICE_NAME"].map { "-" + $0.replacingOccurrences(of: " ", with: "_") } ?? ""
        try screenshot.pngRepresentation.write(to: folder.appending(path: "\(name)\(device).png"))
        try app.debugDescription.write(to: folder.appending(path: "\(name)\(device).txt"), atomically: true, encoding: .utf8)
    }
}
