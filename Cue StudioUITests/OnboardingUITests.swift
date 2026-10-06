//
//  OnboardingUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The first flight: the welcome and five chapters, with and without Apple Intelligence, with the permissions
/// allowed and refused. `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` also saves a picture of each chapter.
@MainActor
final class OnboardingUITests: XCTestCase {
    private func launch(ai: Bool = true, permissions: String = "granted", extra: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-uiTestInMemory", "-uiTestFastAnimations", "-uiTestOnboarding", "-uiTestPermissions", permissions,
            ai ? "-uiTestStubAI" : "-uiTestNoAI",
        ] + extra
        app.launch()
        return app
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// The welcome plays its story first (the stars, the constellation, the words); the buttons arrive last, and only then
    /// exist for accessibility.
    private func startFlight(_ app: XCUIApplication) {
        let start = app.buttons["onboarding.getStarted"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        start.tap()
    }

    /// "Use this script" waits for the script to be written.
    private func useScript(_ app: XCUIApplication) {
        let use = app.buttons["onboarding.useScript"]
        XCTAssertTrue(use.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: use)
        waitForExpectations(timeout: 10)
        use.tap()
    }

    /// Taps a chapter's control once the chapter's transition has put it on screen.
    private func pick(_ app: XCUIApplication, _ id: String) {
        let control = app.buttons[id]
        XCTAssertTrue(control.waitForExistence(timeout: 8), id)
        control.tap()
    }

    private func shot(_ app: XCUIApplication, _ name: String) {
        guard let folder = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { return }
        let directory = URL(fileURLWithPath: folder, isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        sleep(1)
        try? app.screenshot().pngRepresentation.write(to: directory.appending(path: "onboarding-\(name).png"))
    }

    /// Welcome → topics → platform → script → permissions → practice → the studio.
    func testTheFirstFlightWalksFromTheWelcomeToTheStudio() {
        let app = launch()
        let start = app.buttons["onboarding.getStarted"]
        XCTAssertTrue(start.waitForExistence(timeout: 15))
        shot(app, "1-welcome")
        start.tap()

        // 1 · the universe: Continue waits for a topic.
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 5))
        XCTAssertFalse(next.isEnabled)
        app.buttons["onboarding.topic.niche.food"].tap()
        XCTAssertTrue(next.isEnabled)
        app.buttons["onboarding.topic.niche.fitness"].tap()
        shot(app, "2-universe")
        next.tap()

        // 2 · the voyage: a platform and its format line.
        XCTAssertTrue(app.buttons["onboarding.platform.reels"].waitForExistence(timeout: 5))
        app.buttons["onboarding.platform.reels"].tap()
        expectation(for: NSPredicate(format: "label CONTAINS %@", "REELS"), evaluatedWith: element(app, "onboarding.formatLine"))
        expectation(for: NSPredicate(format: "label CONTAINS %@", "9:16"), evaluatedWith: element(app, "onboarding.formatHint"))
        waitForExpectations(timeout: 5)
        shot(app, "3-voyage")
        XCTAssertTrue(app.buttons["onboarding.continue"].label.contains("Reels"))
        app.buttons["onboarding.continue"].tap()

        // 3 · the first script.
        let use = app.buttons["onboarding.useScript"]
        XCTAssertTrue(use.waitForExistence(timeout: 10))
        // Load in teleprompter waits for the message to be written.
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: use)
        waitForExpectations(timeout: 10)
        shot(app, "4-script")
        use.tap()

        // 4 · the permissions: the only button is Continue.
        XCTAssertTrue(element(app, "onboarding.permission.microphone").waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["Not now"].exists, "no way to skip the system alert on this screen")
        shot(app, "5-voice")
        app.buttons["onboarding.continue"].tap()

        // 5 · the practice run: the real prompter, not recording.
        XCTAssertTrue(element(app, "practice.chip").waitForExistence(timeout: 10))
        shot(app, "6-practice")
        app.buttons["practice.notNow"].tap()
        XCTAssertTrue(app.tabBars.buttons["Scripts"].waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "onboarding.root").exists)
        // The script it wrote is in the library, and the platform stuck.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.'")).firstMatch.waitForExistence(timeout: 5))
    }

    /// Without Apple Intelligence the message is the built-in one, and says so.
    func testWithoutAppleIntelligenceTheFirstMessageIsTheBuiltInOne() {
        let app = launch(ai: false)
        startFlight(app)
        pick(app, "onboarding.topic.niche.tech")
        app.buttons["onboarding.continue"].tap()
        pick(app, "onboarding.platform.tiktok")
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.buttons["onboarding.useScript"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["✦ READY · BUILT-IN"].waitForExistence(timeout: 10))
        shot(app, "4b-script-built-in")
    }

    /// A refusal never blocks the flight: it goes on to the practice.
    func testRefusingThePermissionsStillReachesThePractice() {
        let app = launch(permissions: "denied")
        startFlight(app)
        pick(app, "onboarding.topic.niche.food")
        app.buttons["onboarding.continue"].tap()
        pick(app, "onboarding.platform.tiktok")
        app.buttons["onboarding.continue"].tap()
        useScript(app)
        XCTAssertTrue(element(app, "onboarding.permission.microphone").waitForExistence(timeout: 8))
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(element(app, "practice.chip").waitForExistence(timeout: 10))
    }

    /// Each permission row is a button: tapping it asks for that permission, and a refusal is said gently.
    func testThePermissionRowsAreButtons() {
        let app = launch()
        startFlight(app)
        pick(app, "onboarding.topic.niche.food")
        app.buttons["onboarding.continue"].tap()
        pick(app, "onboarding.platform.tiktok")
        app.buttons["onboarding.continue"].tap()
        useScript(app)
        let microphone = app.buttons["onboarding.permission.microphone"]
        XCTAssertTrue(microphone.waitForExistence(timeout: 8))
        microphone.tap()
        let allowed = NSPredicate(format: "label CONTAINS 'Allowed'")
        XCTAssertTrue(element(app, "onboarding.permission.microphone").waitForExistence(timeout: 5))
        expectation(for: allowed, evaluatedWith: element(app, "onboarding.permission.microphone"))
        waitForExpectations(timeout: 5)
        XCTAssertFalse(app.buttons["onboarding.permission.microphone"].exists, "answered: it is no longer a button")
        let camera = app.buttons["onboarding.permission.camera"]
        XCTAssertTrue(camera.exists)
        camera.tap()
        XCTAssertFalse(app.buttons["onboarding.permission.camera"].waitForExistence(timeout: 3))
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(element(app, "practice.chip").waitForExistence(timeout: 10))
    }

    /// A refused permission turns the footnote into a gentle note, and the flight still reaches the practice.
    func testARefusalShowsAGentleNote() {
        let app = launch(permissions: "denied")
        startFlight(app)
        pick(app, "onboarding.topic.niche.food")
        app.buttons["onboarding.continue"].tap()
        pick(app, "onboarding.platform.tiktok")
        app.buttons["onboarding.continue"].tap()
        useScript(app)
        let microphone = app.buttons["onboarding.permission.microphone"]
        XCTAssertTrue(microphone.waitForExistence(timeout: 8))
        microphone.tap()
        XCTAssertTrue(element(app, "onboarding.permission.deniedNote").waitForExistence(timeout: 5))
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(element(app, "practice.chip").waitForExistence(timeout: 10))
    }

    /// The practice has the recorder's own controls (Voice | Steady, play, speed) over the camera, and both ways out stay in reach.
    func testThePracticeHasTheRecordersControlsAndBothWaysOut() {
        let app = launch()
        startFlight(app)
        pick(app, "onboarding.topic.niche.food")
        app.buttons["onboarding.continue"].tap()
        pick(app, "onboarding.platform.tiktok")
        app.buttons["onboarding.continue"].tap()
        useScript(app)
        XCTAssertTrue(element(app, "onboarding.permission.microphone").waitForExistence(timeout: 8))
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(element(app, "practice.chip").waitForExistence(timeout: 10))
        // The practice is the board's 1.6: the text, play, and the two ways out (no Voice | Steady switch: that is the recorder's).
        XCTAssertTrue(app.buttons["practice.play"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["practice.recordForReal"].isHittable)
        XCTAssertTrue(app.buttons["practice.notNow"].isHittable)
        shot(app, "6b-practice-controls")
    }

    /// Skip goes straight to the Scripts empty state.
    func testSkipGoesToTheEmptyScriptsScreen() {
        let app = launch()
        startFlight(app)
        XCTAssertTrue(app.buttons["onboarding.skip"].waitForExistence(timeout: 5))
        app.buttons["onboarding.skip"].tap()
        XCTAssertTrue(element(app, "empty.promptCard").waitForExistence(timeout: 10))
        XCTAssertFalse(element(app, "onboarding.root").exists)
    }

    /// "+ Your own" adds a topic of their own.
    func testATopicOfTheirOwn() {
        let app = launch()
        startFlight(app)
        pick(app, "onboarding.topic.own")
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("Budget travel")
        app.buttons["Add"].tap()
        // It joins the list as a chip, picked; tapping it lets go, and again picks it back.
        let chip = app.buttons["onboarding.topic.custom.budget travel"]
        XCTAssertTrue(chip.waitForExistence(timeout: 5))
        XCTAssertTrue(chip.isSelected)
        XCTAssertTrue(app.buttons["onboarding.continue"].isEnabled)
        chip.tap()
        XCTAssertTrue(chip.exists, "let go of, the chip stays in the list")
        XCTAssertFalse(chip.isSelected)
        XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)
        chip.tap()
        XCTAssertTrue(chip.isSelected)
    }

    /// 1.2: a word Apple Intelligence won't use is refused inline, and nothing is added.
    func testABlockedWordInATopicOfTheirOwnIsRefused() {
        let app = launch()
        startFlight(app)
        pick(app, "onboarding.topic.own")
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 5))
        field.typeText("holy shit")
        app.buttons["Add"].tap()
        XCTAssertTrue(app.staticTexts["Apple Intelligence can’t use this word."].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.continue"].isEnabled)
    }
}
