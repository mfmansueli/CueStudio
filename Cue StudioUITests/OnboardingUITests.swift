//
//  OnboardingUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The first flight: the welcome and five chapters, with the permissions allowed and refused, and the practice's Voice Following ready,
/// getting ready, unavailable or without the microphone. `TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>` also saves a picture of each chapter.
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

    /// "Try the teleprompter" is there once the practice script has arrived.
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
        // Try the teleprompter is enabled once the practice script is there.
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
        // The practice script is in the library, and the platform stuck.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'scripts.row.'")).firstMatch.waitForExistence(timeout: 5))
    }

    /// 1.4 is the practice script, the same with or without Apple Intelligence, with the time it really takes to read (59 words: 24 s).
    func testTheFirstScriptIsThePracticeScriptWithItsReadingTime() {
        let app = launch(ai: false)
        startFlight(app)
        pick(app, "onboarding.topic.niche.tech")
        app.buttons["onboarding.continue"].tap()
        pick(app, "onboarding.platform.tiktok")
        app.buttons["onboarding.continue"].tap()
        XCTAssertTrue(app.buttons["onboarding.useScript"].waitForExistence(timeout: 10))
        XCTAssertEqual(app.buttons["onboarding.useScript"].label, "Try the teleprompter")
        XCTAssertTrue(app.staticTexts["✦ PRACTICE SCRIPT · READY"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["24 SEC"].exists)
        XCTAssertFalse(app.staticTexts["15 SEC"].exists)
        XCTAssertTrue(app.staticTexts["It’s just practice. Nothing is recorded."].exists)
        shot(app, "4-script-practice")
    }

    // MARK: - Voice Following in the practice

    /// From the permissions to the practice, with Voice Following's recognition scripted (the simulator can't recognize speech).
    private func practice(voice: String, permissions: String = "granted") -> XCUIApplication {
        let app = launch(permissions: permissions, extra: ["-uiTestOnboardingStep", "voice", "-uiTestVoiceFollowing", voice])
        let next = app.buttons["onboarding.continue"]
        XCTAssertTrue(next.waitForExistence(timeout: 10))
        next.tap()
        XCTAssertTrue(element(app, "practice.chip").waitForExistence(timeout: 10))
        return app
    }

    private func expectVoiceStatus(_ app: XCUIApplication, _ text: String) {
        let status = element(app, "practice.voiceStatus")
        XCTAssertTrue(status.waitForExistence(timeout: 10))
        expectation(for: NSPredicate(format: "value == %@", text), evaluatedWith: status)
        waitForExpectations(timeout: 10)
    }

    /// With the microphone and recognition ready, the practice starts with Voice Following on and says so.
    func testThePracticeStartsWithVoiceFollowingOn() {
        let app = practice(voice: "listening")
        expectVoiceStatus(app, "Voice Following is on")
        XCTAssertTrue(app.staticTexts["Tap play and wait for the count. Then read out loud: the text follows your voice."].exists)
        XCTAssertFalse(element(app, "practice.microphoneOff").exists)
        shot(app, "6c-practice-voice-on")
        XCTAssertFalse(app.buttons["practice.recordForReal"].exists)
        // Started: nobody speaks, so the text waits for the voice, and the way to record is there.
        app.buttons["practice.play"].tap()
        XCTAssertTrue(app.buttons["practice.recordForReal"].waitForExistence(timeout: 5))
        expectVoiceStatus(app, "Waiting for your voice")
    }

    func testThePracticeSaysWhileRecognitionGetsReady() {
        let app = practice(voice: "preparing")
        expectVoiceStatus(app, "Getting ready to follow your voice")
        shot(app, "6d-practice-voice-preparing")
    }

    /// Words this iPhone can't follow: the text moves while the creator talks, and the card says that instead.
    func testWhenWordsCantBeFollowedThePracticeSaysTheTextMovesWhileYouTalk() {
        let app = practice(voice: "unavailable")
        expectVoiceStatus(app, "Moves while you talk")
        XCTAssertTrue(app.staticTexts["Tap play and wait for the count. Then read out loud: the text moves while you talk."].waitForExistence(timeout: 5))
        shot(app, "6e-practice-voice-unavailable")
    }

    /// The microphone refused: a steady scroll, said plainly, with the way to Settings.
    func testWithoutTheMicrophoneThePracticeScrollsSteadilyAndSaysSo() {
        let app = practice(voice: "listening", permissions: "denied")
        expectVoiceStatus(app, "Microphone off · Steady scroll")
        XCTAssertTrue(element(app, "practice.microphoneOff").exists)
        XCTAssertTrue(app.staticTexts["Tap play and wait for the count. Then read: the text scrolls at a steady pace."].exists)
        shot(app, "6f-practice-microphone-off")
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

    /// The practice has play over the camera and the way out; "Record my first video" waits for the tap on play.
    func testThePracticeHasPlayAndTheWayOutAndRecordWaitsForPlay() {
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
        // The practice is the board's 1.6: the text, play, and the way out (no Voice | Steady switch: that is the recorder's).
        XCTAssertTrue(app.buttons["practice.play"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["practice.notNow"].isHittable)
        XCTAssertFalse(app.buttons["practice.recordForReal"].exists)
        shot(app, "6b-practice-controls")
    }

    /// The flight can't be skipped: no Skip on any chapter, and 1.1 has only Get started.
    func testTheFlightHasNoWayToSkipIt() {
        let app = launch()
        XCTAssertTrue(app.buttons["onboarding.getStarted"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["onboarding.returning"].exists)
        startFlight(app)
        XCTAssertTrue(app.buttons["onboarding.continue"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["onboarding.skip"].exists)
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
