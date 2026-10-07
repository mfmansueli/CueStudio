//
//  ButtonPromisesUITests.swift
//  Cue StudioUITests
//

import XCTest

/// A button does what its name says, and every road leads somewhere and back: the findings of walking the whole app as a creator does, kept as tests.
/// Each test is a promise a label makes (the Logbook button listens, "Show every video" shows every video, a switch flips and stays flipped, a tool
/// changes the script and Undo takes it back). The words an AI tool writes are measured on a real iPhone (`ScriptToolsDeviceTests`); here the stub writer
/// marks each tool, so what is checked is that the button runs its own tool and tells the truth about it.
@MainActor
final class ButtonPromisesUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// A picture of the screen as it is, for the failures that need looking at (`TEST_RUNNER_CUE_HUNT_DIR=<folder>`).
    private func snap(_ app: XCUIApplication, _ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["CUE_HUNT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "promise-\(name).png"))
        try? app.debugDescription.write(to: directory.appending(path: "promise-\(name).txt"), atomically: true, encoding: .utf8)
    }

    /// The value a switch has once it has had a moment to change (a tap is answered a frame later).
    private func value(of toggle: XCUIElement, differentFrom old: String?) -> String? {
        let deadline = Date().addingTimeInterval(4)
        func current() -> String? { toggle.exists ? toggle.value as? String : old }
        while Date() < deadline, current() == old { usleep(200_000) }
        return current()
    }

    /// A finger on the switch itself, where a person puts it (the row's middle is its words).
    private func flip(_ toggle: XCUIElement) {
        toggle.coordinate(withNormalizedOffset: CGVector(dx: 0.93, dy: 0.5)).tap()
    }

    private func goToTab(_ app: XCUIApplication, _ name: String) {
        let tab = app.cueTabBar.buttons[name]
        XCTAssertTrue(tab.waitForExistence(timeout: 15))
        tab.tap()
    }

    // MARK: - The Logbook button

    func testATapOnTheLogbookButtonListensUntilItIsTappedAgain() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDictation", "speech", "-uiTestDictationText", "a video about slow mornings"])
        app.buttons["scripts.logbookButton"].tap()
        let button = element(app, "logbook.captureButton")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        // A tap is not a hold, and it is not nothing: it keeps listening and says how to finish.
        XCTAssertTrue(element(app, "logbook.tapToFinish").waitForExistence(timeout: 5), "A tap on the button did nothing")
        // The words arrive in the field while it listens (the Logbook of the native-bars rework), and the next tap saves them.
        let field = element(app, "logbook.field")
        let heard = NSPredicate(format: "value CONTAINS 'slow mornings'")
        XCTAssertEqual(XCTWaiter().wait(for: [XCTNSPredicateExpectation(predicate: heard, object: field)], timeout: 10), .completed, "Nothing was heard")
        button.tap()
        XCTAssertTrue(element(app, "logbook.entry").waitForExistence(timeout: 10), "The idea it heard did not reach the Logbook")
        XCTAssertFalse(element(app, "logbook.tapToFinish").exists)
    }

    func testHoldingTheLogbookButtonCapturesWhileItIsHeld() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDictation", "speech", "-uiTestDictationText", "one more idea"])
        app.buttons["scripts.logbookButton"].tap()
        let button = element(app, "logbook.captureButton")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.press(forDuration: 2.5)
        XCTAssertTrue(element(app, "logbook.entry").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "logbook.tapToFinish").exists, "A hold ended with the finger and has no tap to finish")
    }

    func testATapWhereNothingCanListenSaysWhyAndStops() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestDictation", "unavailable"])
        app.buttons["scripts.logbookButton"].tap()
        let button = element(app, "logbook.captureButton")
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
        XCTAssertTrue(
            app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'turn speech into text' OR label CONTAINS 'recognize'")).firstMatch
                .waitForExistence(timeout: 5),
            "No reason was given"
        )
        XCTAssertFalse(element(app, "logbook.tapToFinish").exists, "It keeps listening to nothing")
    }

    // MARK: - The card's "another idea"

    /// "↻" is a promise of another idea: ten taps bring many different ones, not the same three over and over (the starters are three for each topic;
    /// the model's, six at a time, take their place).
    func testAnotherIdeaKeepsBringingNewOnes() {
        let app = CueApp.launch(seeded: true)
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        let another = element(app, "ideaCard.anotherIdea")
        XCTAssertTrue(another.waitForExistence(timeout: 10))
        // Let the first batch of the model's ideas arrive (the stub answers at once).
        sleep(2)
        var shown = Set<String>()
        for _ in 0..<10 {
            shown.insert(field.value as? String ?? "")
            another.tap()
            usleep(300_000)
        }
        XCTAssertGreaterThanOrEqual(shown.count, 8, "↻ brought only \(shown.count) different ideas in ten taps: \(shown)")
    }

    // MARK: - The tools of "Improve script"

    /// The page's own "Improve" chip: the same sheet as the menu's "Improve with Cue", without a system menu in the way.
    private func openImprove(_ app: XCUIApplication) {
        let chip = app.buttons["page.improveButton"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5), "The page has no Improve button")
        chip.tap()
        if !app.buttons["improve.tool.inMyVoice"].waitForExistence(timeout: 5) { snap(app, "improve-sheet") }
        XCTAssertTrue(app.buttons["improve.tool.inMyVoice"].exists, "The Improve sheet did not open")
    }

    /// The sheet opens half way, with the tool further down its list: drag its list up until the tool is fully on the screen.
    private func scrollSheet(_ app: XCUIApplication, to button: XCUIElement) {
        var drags = 0
        while button.frame.maxY > app.frame.height - 40, drags < 5 {
            let from = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.85))
            from.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
            drags += 1
        }
    }

    private func editorText(_ app: XCUIApplication) -> String {
        (element(app, "page.editor").value as? String) ?? ""
    }

    func testEachToolOfASponsoredScriptRunsItsOwnToolAndUndoTakesItBack() {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Oat & Co. — sponsored read")
        let original = editorText(app)
        for tool in ["inMyVoice", "strongerCTA", "fitToTime"] {
            openImprove(app)
            let button = app.buttons["improve.tool.\(tool)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No \(tool) in the sheet of a sponsored script")
            scrollSheet(app, to: button)
            button.tap()
            XCTAssertTrue(app.buttons["toast.action"].waitForExistence(timeout: 10), "\(tool): nothing was said")
            XCTAssertTrue(editorText(app).contains("Rewritten with \(tool)."), "\(tool): the script is not what the tool wrote")
            app.buttons["toast.action"].tap()
            XCTAssertEqual(editorText(app), original, "\(tool): Undo did not bring the script back")
        }
    }

    func testDisclosureGoesUpFrontOnceAndSaysSoTheSecondTime() {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Oat & Co. — sponsored read")
        openImprove(app)
        scrollSheet(app, to: app.buttons["improve.tool.addDisclosure"])
        app.buttons["improve.tool.addDisclosure"].tap()
        XCTAssertTrue(app.staticTexts["Disclosure added up front"].waitForExistence(timeout: 5))
        XCTAssertTrue(editorText(app).contains("paid partnership"))
        openImprove(app)
        scrollSheet(app, to: app.buttons["improve.tool.addDisclosure"])
        app.buttons["improve.tool.addDisclosure"].tap()
        XCTAssertTrue(app.staticTexts["Disclosure is already first"].waitForExistence(timeout: 5))
    }

    func testEachToolOfAPlainScriptRunsItsOwnToolAndUndoTakesItBack() {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        let original = editorText(app)
        for tool in ["fixGrammar", "moreEnergy"] {
            openImprove(app)
            let button = app.buttons["improve.tool.\(tool)"]
            XCTAssertTrue(button.waitForExistence(timeout: 5), "No \(tool) in the sheet")
            // The sheet opens half way: the tool may be further down the list.
            scrollSheet(app, to: button)
            button.tap()
            if !app.buttons["toast.action"].waitForExistence(timeout: 3) {
                let said = app.staticTexts.allElementsBoundByIndex.map(\.label).filter { $0.count > 12 && $0.count < 80 }
                XCTFail("\(tool) said: \(said)")
                snap(app, "tool-\(tool)")
            }
            XCTAssertTrue(app.buttons["toast.action"].exists, "\(tool): nothing was said")
            XCTAssertTrue(editorText(app).contains("Rewritten with \(tool)."))
            app.buttons["toast.action"].tap()
            XCTAssertEqual(editorText(app), original)
        }
    }

    func testATranslationIsANewScriptAndTheOriginalStays() {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Unboxing the Lumen desk lamp")
        let original = editorText(app)
        openImprove(app)
        scrollSheet(app, to: app.buttons["improve.tool.translate"])
        app.buttons["improve.tool.translate"].tap()
        let spanish = app.buttons["Spanish"]
        XCTAssertTrue(spanish.waitForExistence(timeout: 5), "The translate menu offers no language")
        spanish.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'version saved'")).firstMatch.waitForExistence(timeout: 10))
        XCTAssertEqual(editorText(app), original, "The script that was translated changed")
        app.pageBackButton.tap()
        XCTAssertTrue(app.staticTexts["Unboxing the Lumen desk lamp (Spanish)"].waitForExistence(timeout: 10) || app.scriptRowExists(containing: "(Spanish)"))
    }

    func testAToolHasNothingToWorkOnInABlankScript() {
        let app = CueApp.launch(seeded: true)
        app.buttons["scripts.newButton"].tap()
        app.buttons["newScript.write"].tap()
        XCTAssertTrue(app.buttons["page.menuButton"].waitForExistence(timeout: 5))
        openImprove(app)
        scrollSheet(app, to: app.buttons["improve.tool.moreEnergy"])
        app.buttons["improve.tool.moreEnergy"].tap()
        XCTAssertTrue(
            app.staticTexts["Write something first, then Cue can improve it"].waitForExistence(timeout: 5),
            "A tool ran on a script with nothing in it, or said nothing"
        )
        XCTAssertFalse(editorText(app).contains("Rewritten"))
    }

    // MARK: - Takes

    func testAnEmptyFilteredListOffersEveryVideoBack() {
        let app = CueApp.launch(seeded: true)
        goToTab(app, "Takes")
        let ready = app.buttons["takes.stage.ready"]
        XCTAssertTrue(ready.waitForExistence(timeout: 10))
        ready.tap()
        app.buttons["takes.platform.shorts"].tap()
        let empty = element(app, "takes.emptyStage")
        XCTAssertTrue(empty.waitForExistence(timeout: 5), "A list with nothing in it said nothing")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS 'Shorts'")).count > 0, "It does not say which platform has nothing")
        let showAll = app.buttons["takes.showAll"]
        if !showAll.waitForExistence(timeout: 5) { snap(app, "takes-empty") }
        XCTAssertTrue(showAll.exists, "An empty list is a dead end")
        showAll.tap()
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.'")).firstMatch.waitForExistence(timeout: 5))
        XCTAssertFalse(element(app, "takes.emptyStage").exists)
        XCTAssertFalse(ready.isSelected, "The stage is still picked after showing everything")
    }

    // MARK: - Settings

    private func openSettingsPage(_ app: XCUIApplication, _ id: String) {
        goToTab(app, "Settings")
        let row = element(app, "settings.\(id)")
        app.scroll(to: row)
        row.tap()
    }

    private func backToSettings(_ app: XCUIApplication) {
        app.navigationBars.buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
    }

    func testEverySwitchOfSettingsFlipsAndKeepsItsValue() {
        let app = CueApp.launch(seeded: true)
        let pages: [(page: String, switches: [String])] = [
            ("recording", ["settings.grid"]),
            ("prompter", ["settings.aiCoach", "settings.showReadingLine", "settings.mirrorText", "settings.flipVertically"]),
            ("personalize", ["settings.autoTag", "settings.celebrations", "settings.haptics"]),
        ]
        for (page, ids) in pages {
            for id in ids {
                openSettingsPage(app, page)
                let toggle = app.switches[id]
                app.scroll(to: toggle)
                let before = toggle.value as? String
                XCTAssertTrue(toggle.isEnabled, "\(id) is off for good")
                flip(toggle)
                let after = value(of: toggle, differentFrom: before)
                XCTAssertNotEqual(before, after, "\(id): the switch did not flip")
                // Out of the page and back: it is still as it was left.
                backToSettings(app)
                openSettingsPage(app, page)
                let again = app.switches[id]
                app.scroll(to: again)
                XCTAssertEqual(again.value as? String, after, "\(id): the choice was forgotten")
                usleep(500_000)
                flip(again)
                // A tap that lands while the page is still settling after it was opened is lost on a busy simulator: a person taps again.
                if value(of: again, differentFrom: after) == after {
                    usleep(800_000)
                    flip(again)
                }
                XCTAssertEqual(value(of: again, differentFrom: after), before, "\(id): it does not flip back")
                backToSettings(app)
            }
        }
    }

    func testFlippingTheTextVerticallyKeepsTheSettingsPageWhereItWas() {
        let app = CueApp.launch(seeded: true)
        openSettingsPage(app, "prompter")
        let toggle = app.switches["settings.flipVertically"]
        app.scroll(to: toggle)
        let before = toggle.frame.minY
        snap(app, "flip-before")
        flip(toggle)
        sleep(1)
        snap(app, "flip-after")
        XCTAssertTrue(toggle.waitForExistence(timeout: 3), "The switch left the page when it was tapped")
        XCTAssertEqual(toggle.frame.minY, before, accuracy: 4, "The page moved under the finger")
    }

    func testEveryRowOfMyCueVoiceOpensItsEditorFromSettings() {
        let app = CueApp.launch(seeded: true)
        openSettingsPage(app, "myCueVoice")
        XCTAssertTrue(element(app, "voicePage").waitForExistence(timeout: 10))
        let rows = ["role", "topics", "audience", "watch", "tone", "style", "formats", "openings", "endings", "phrases", "avoid", "examples"]
        var opened = 0
        for row in rows {
            let button = app.buttons["voicePage.row.\(row)"]
            if !button.exists { app.swipeUp() }
            guard button.waitForExistence(timeout: 3) else { continue }
            app.scroll(to: button)
            button.tap()
            let editor = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH 'voice.editor.'")).firstMatch
            XCTAssertTrue(editor.waitForExistence(timeout: 5), "The row \(row) opens nothing")
            opened += 1
            let done = app.buttons["voice.editor.done"]
            XCTAssertTrue(done.waitForExistence(timeout: 5), "The editor of \(row) has no way out")
            done.tap()
            XCTAssertTrue(element(app, "voicePage").waitForExistence(timeout: 5), "Done in the editor of \(row) did not come back to the page")
        }
        XCTAssertGreaterThanOrEqual(opened, 8, "Too few rows were found to open")
    }

    // MARK: - Profile

    func testTheCoreColourThatIsPickedIsTheOneSelected() {
        let app = CueApp.launch(seeded: true)
        goToTab(app, "Profile")
        let universe = element(app, "profile.universeLink")
        app.scroll(to: universe)
        universe.tap()
        let core = element(app, "universe.core")
        XCTAssertTrue(core.waitForExistence(timeout: 10))
        core.tap()
        for colour in ["rose", "amber", "sunrise", "gold"] {
            let chip = app.buttons["coreColor.\(colour)"]
            XCTAssertTrue(chip.waitForExistence(timeout: 5), "No \(colour)")
            chip.tap()
            XCTAssertTrue(chip.isSelected, "\(colour) was tapped and is not the one selected")
        }
    }
}

private extension XCUIApplication {
    /// A script row of Scripts whose title has `text`.
    func scriptRowExists(containing text: String) -> Bool {
        buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.' AND label CONTAINS %@", text)).firstMatch.waitForExistence(timeout: 5)
    }
}
