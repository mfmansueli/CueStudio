//
//  PerformanceDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// How Cue performs on a real iPhone, with XCTest's own metrics: the cold launch, scrolling Scripts over the sky, opening a take
/// in the editor, opening Profile's universe, the idea's star, the Logbook and typing in a long script (time, memory, CPU, scroll and
/// animation hitches). In
/// memory and seeded, so the owner's library is never touched; real animations, as a creator sees them. Opt-in (a Debug build: compare
/// runs with each other, not with the App Store's): `CUE_DEVICE=… TEST_RUNNER_CUE_PERF=1 scripts/test.sh device-ui PerformanceDeviceUITests`.
@MainActor
final class PerformanceDeviceUITests: XCTestCase {
    private var options: XCTMeasureOptions {
        let options = XCTMeasureOptions()
        options.iterationCount = 5
        return options
    }

    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_PERF"] != nil else {
            throw XCTSkip("Device measurement: TEST_RUNNER_CUE_PERF=1")
        }
    }

    /// From the tap on the icon to the first screen that answers touches.
    func testColdLaunch() {
        // XCTest runs the block on the main thread.
        measure(metrics: [XCTApplicationLaunchMetric(waitUntilResponsive: true)], options: options) {
            MainActor.assumeIsolated {
                let app = XCUIApplication()
                app.launchArguments = ["-uiTestInMemory", "-uiTestSeedSamples", "-uiTestStubAI"]
                app.launch()
            }
        }
    }

    /// Scripts' list, flung up and down over the sky: hitches while it scrolls and slows, memory and CPU.
    func testScrollingScriptsOverTheSky() {
        let app = CueApp.launch(seeded: true, animations: true, extraArguments: ["-uiTestSky", "interstellar"])
        let list = app.collectionViews.firstMatch
        XCTAssertTrue(list.exists(within: 15))
        let metrics: [any XCTMetric] = [
            XCTOSSignpostMetric.scrollingAndDecelerationMetric, XCTMemoryMetric(application: app), XCTCPUMetric(application: app),
        ]
        // XCTest runs the block on the main thread.
        measure(metrics: metrics, options: options) {
            MainActor.assumeIsolated {
                list.swipeUp(velocity: .fast)
                list.swipeDown(velocity: .fast)
            }
        }
    }

    /// A take's review, Edit, the editor ready (its tools on), and back: how long, and the memory the editor keeps.
    func testOpeningATakeInTheEditor() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, animations: true)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.exists(within: 10))
        // XCTest runs the block on the main thread.
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(application: app), XCTCPUMetric(application: app)], options: options) {
            MainActor.assumeIsolated {
                row.tap()
                let edit = app.buttons["review.editButton"]
                XCTAssertTrue(edit.exists(within: 10))
                edit.tap()
                EditorApp.waitUntilReady(app)
                app.buttons["edit.backButton"].tap()
                let back = app.buttons["review.backButton"]
                XCTAssertTrue(back.exists(within: 10))
                back.tap()
                XCTAssertTrue(row.exists(within: 10))
            }
        }
    }

    /// Only the wait the creator sees after Edit ("Getting your take ready"): from the tap to the editor's tools turning on.
    func testTheEditorGettingReady() {
        let app = CueApp.launch(seeded: true, sampleVideo: true, animations: true)
        let tab = app.cueTabBar.buttons["Takes"]
        XCTAssertTrue(tab.exists(within: 15))
        tab.tap()
        let row = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'takes.video.' AND label CONTAINS '3 morning habits'")).firstMatch
        XCTAssertTrue(row.exists(within: 10))
        let options = options
        options.invocationOptions = [.manuallyStart, .manuallyStop]
        // XCTest runs the block on the main thread.
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app)], options: options) {
            MainActor.assumeIsolated {
                row.tap()
                let edit = app.buttons["review.editButton"]
                XCTAssertTrue(edit.exists(within: 10))
                startMeasuring()
                edit.tap()
                EditorApp.waitUntilReady(app)
                stopMeasuring()
                app.buttons["edit.backButton"].tap()
                let back = app.buttons["review.backButton"]
                XCTAssertTrue(back.exists(within: 10))
                back.tap()
                XCTAssertTrue(row.exists(within: 10))
            }
        }
    }

    /// Profile with the year's universe drawn, from the tab: time, memory and CPU while it draws.
    func testOpeningTheUniverse() {
        let app = CueApp.launch(seeded: true, animations: true, extraArguments: ["-uiTestUniverse", "sample"])
        let profile = app.cueTabBar.buttons["Profile"]
        let scripts = app.cueTabBar.buttons["Scripts"]
        XCTAssertTrue(profile.exists(within: 15))
        // XCTest runs the block on the main thread.
        measure(metrics: [XCTClockMetric(), XCTMemoryMetric(application: app), XCTCPUMetric(application: app)], options: options) {
            MainActor.assumeIsolated {
                profile.tap()
                XCTAssertTrue(app.buttons["profile.upgradeButton"].exists(within: 10) || app.navigationBars["Profile"].exists(within: 5))
                scripts.tap()
                XCTAssertTrue(app.collectionViews.firstMatch.exists(within: 10))
            }
        }
    }

    /// The idea's star rising from the arrow as a creator sends one, with the iPhone's own Apple Intelligence starting to write under it:
    /// hitches while it rises and the app dims behind it ("Star rise"), then Cancel. Nothing asks the app anything while it rises, so the
    /// test's own questions don't cost it frames.
    func testSendingAnIdea() {
        let app = CueApp.launch(seeded: true, ai: .appleIntelligence, animations: true, extraArguments: ["-uiTestStarTransition"])
        let send = app.buttons["ideaCard.submit"]
        XCTAssertTrue(send.exists(within: 15))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: send)
        waitForExpectations(timeout: 60)
        let cancel = app.buttons["transition.cancel"]
        let rise = XCTOSSignpostMetric(subsystem: "studio.cue", category: "Motion", name: "Star rise")
        // XCTest runs the block on the main thread.
        measure(metrics: [rise], options: options) {
            MainActor.assumeIsolated {
                send.tap()
                Thread.sleep(forTimeInterval: 1.6)
                cancel.tap()
                expectation(for: NSPredicate(format: "exists == false"), evaluatedWith: cancel)
                waitForExpectations(timeout: 10)
            }
        }
    }

    /// The script ready: the cover, the ring opening onto the page, the star landing as the caret and the first words arriving at their
    /// real pace ("Star reveal"), then back to Scripts.
    func testTheStarOpeningTheScript() {
        let app = CueApp.launch(seeded: true, animations: true, extraArguments: ["-uiTestStarTransition", "-uiTestRealWriting"])
        let send = app.buttons["ideaCard.submit"]
        XCTAssertTrue(send.exists(within: 15))
        let reveal = XCTOSSignpostMetric(subsystem: "studio.cue", category: "Motion", name: "Star reveal")
        // XCTest runs the block on the main thread.
        measure(metrics: [reveal], options: options) {
            MainActor.assumeIsolated {
                send.tap()
                // The 3 s the star lasts at least, and its finish.
                Thread.sleep(forTimeInterval: 6.5)
                XCTAssertTrue(app.pageBackButton.exists(within: 10))
                app.pageBackButton.tap()
                XCTAssertTrue(send.exists(within: 10))
            }
        }
    }

    /// The Logbook's microphone held for a moment and let go, five times: the iPhone's own microphone and speech recognition start under
    /// the circle's jump and its rings, and stop. Silence is heard, so nothing is saved and each run is the same. Hitches as listening
    /// starts ("Logbook listen").
    /// Needs the microphone and speech recognition allowed for Cue on the iPhone.
    func testHoldingTheLogbooksMicrophone() {
        let app = CueApp.launch(seeded: true, animations: true)
        app.buttons["scripts.logbookButton"].tap()
        let microphone = app.descendants(matching: .any)["logbook.captureButton"].firstMatch
        XCTAssertTrue(microphone.exists(within: 5))
        // XCTest runs the block on the main thread.
        let listen = XCTOSSignpostMetric(subsystem: "studio.cue", category: "Motion", name: "Logbook listen")
        measure(metrics: [listen], options: options) {
            MainActor.assumeIsolated {
                microphone.press(forDuration: 1.5)
                Thread.sleep(forTimeInterval: 1)
            }
        }
    }

    /// The first idea sent after a launch, five launches: the app opened from nothing, with the iPhone's own Apple Intelligence, and its
    /// card's idea sent as soon as it can be. How long each step of the send keeps the main thread (`studio.cue` / Send, from the tap to the
    /// star's first frame), and the rise's hitches. What stood still was the first send only (the owner's recording, 26/10/2026).
    func testTheFirstSendAfterALaunch() {
        let steps: [StaticString] = [
            "Idea send", "Drafting check", "Takeoff haptic", "Next idea", "Idea request", "Language check", "Script created", "Page opened",
        ]
        var metrics: [any XCTMetric] = steps.map { XCTOSSignpostMetric(subsystem: "studio.cue", category: "Send", name: "\($0)") }
        metrics.append(XCTOSSignpostMetric(subsystem: "studio.cue", category: "Motion", name: "Star rise"))
        // XCTest runs the block on the main thread.
        measure(metrics: metrics, options: options) {
            MainActor.assumeIsolated {
                let app = CueApp.launch(seeded: true, ai: .appleIntelligence, animations: true, extraArguments: ["-uiTestStarTransition"])
                let send = app.buttons["ideaCard.submit"]
                XCTAssertTrue(send.exists(within: 15))
                expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: send)
                waitForExpectations(timeout: 30)
                send.tap()
                Thread.sleep(forTimeInterval: 2.5)
                app.terminate()
            }
        }
    }

    /// Forty letters typed into the words of a long script (the stub's, 443 words), five times: the app's CPU and how long the typing
    /// takes. A letter should cost only the field it lands in, never the page around it (the owner felt each one lag, 03/11/2026).
    func testTypingInALongScriptsWords() {
        let app = openLongScript()
        let words = app.textViews["page.editor"]
        words.tap()
        // XCTest runs the block on the main thread.
        measure(metrics: Self.typingMetrics(app), options: options) {
            MainActor.assumeIsolated { words.typeText(Self.typed) }
        }
    }

    /// The same letters typed into a short script's words (15 words): what typing costs whatever the length, to tell from the long one.
    func testTypingInAShortScriptsWords() {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: "Cold showers: one month in")
        let words = app.textViews["page.editor"]
        XCTAssertTrue(words.exists(within: 10))
        words.tap()
        // XCTest runs the block on the main thread.
        measure(metrics: Self.typingMetrics(app), options: options) {
            MainActor.assumeIsolated { words.typeText(Self.typed) }
        }
    }

    /// The same forty letters typed into the long script's title.
    func testTypingInALongScriptsTitle() {
        let app = openLongScript()
        let title = app.textFields["page.titleField"]
        title.tap()
        // XCTest runs the block on the main thread.
        measure(metrics: [XCTClockMetric(), XCTCPUMetric(application: app)], options: options) {
            MainActor.assumeIsolated { title.typeText(Self.typed) }
        }
    }

    private static let typed = "and then one more line to see it feel "

    /// Words typed one at a time in the middle of the long script Ultra AI wrote (`SampleAIDraft`: 800 words in Portuguese, language on
    /// Auto-detect, the fact check waiting) with the real Apple Intelligence: what the owner typed into when the words lagged (03/11/2026).
    /// Each word is followed by the pause XCTest takes between two, so the page's measures catch up (and the words are saved) as they do
    /// for a creator. The probe (`ScriptTypingProbe`) says how many frames the main thread missed and how long a letter took to show.
    func testTypingInAnAIDraft() throws {
        let app = CueApp.launch(seeded: true, ai: .appleIntelligence, extraArguments: ["-uiTestAIDraft", "-uiTestTypingProbe"])
        app.openScriptPage(titled: "Acordei às 5h por 30 dias: o que ninguém te conta")
        probeTyping(in: app, named: "the AI's draft")
    }

    /// The same words typed the same way into a short draft (15 words): what XCTest's typing costs the app whatever the script, to tell from
    /// what the long one adds.
    func testTypingInAShortDraft() throws {
        let app = CueApp.launch(seeded: true, ai: .appleIntelligence, extraArguments: ["-uiTestTypingProbe"])
        app.openScriptPage(titled: "Cold showers: one month in")
        probeTyping(in: app, named: "a short draft")
    }

    /// The AI's draft again, typed by the app itself at a person's pace (`ScriptTypingRobot`): XCTest stays out of the way, so the probe
    /// measures only what a letter costs the app. The same for the short draft, to compare.
    func testTypingInAnAIDraftAtAPersonsPace() throws {
        let app = CueApp.launch(seeded: true, ai: .appleIntelligence, extraArguments: ["-uiTestAIDraft", "-uiTestTypingProbe", "-uiTestAutoType"])
        app.openScriptPage(titled: "Acordei às 5h por 30 dias: o que ninguém te conta")
        probeRobotTyping(in: app, named: "the AI's draft at a person's pace")
    }

    func testTypingInAShortDraftAtAPersonsPace() throws {
        let app = CueApp.launch(seeded: true, ai: .appleIntelligence, extraArguments: ["-uiTestTypingProbe", "-uiTestAutoType"])
        app.openScriptPage(titled: "Cold showers: one month in")
        probeRobotTyping(in: app, named: "a short draft at a person's pace")
    }

    private func probeRobotTyping(in app: XCUIApplication, named name: String) {
        let words = app.textViews["page.editor"]
        XCTAssertTrue(words.exists(within: 10))
        words.tap()
        // A second, then 61 letters at 90 ms and 13 breaths of 350 ms; nothing asked of the app meanwhile.
        Thread.sleep(forTimeInterval: 12)
        report(words, named: name)
    }

    private func probeTyping(in app: XCUIApplication, named name: String) {
        let words = app.textViews["page.editor"]
        XCTAssertTrue(words.exists(within: 10))
        words.tap()
        for word in Self.typedInPortuguese.split(separator: " ") {
            words.typeText(word + " ")
        }
        // The probe speaks 0.6 s after the last letter.
        Thread.sleep(forTimeInterval: 1.5)
        report(words, named: name)
    }

    private func report(_ words: XCUIElement, named name: String) {
        let probe = NSPredicate(format: "label CONTAINS %@", "probe keys=")
        expectation(for: probe, evaluatedWith: words)
        waitForExpectations(timeout: 10)
        let numbers = Self.probeNumbers(in: words.label)
        let report = words.label.components(separatedBy: "probe ").last ?? ""
        XCTContext.runActivity(named: "Typing in \(name): \(report)") { activity in
            activity.add(XCTAttachment(string: words.label))
        }
        XCTAssertGreaterThan(numbers["keys"] ?? 0, 40, "The probe heard fewer letters than were typed")
        // The words' frame is never shorter than the words: a last line cut off is a broken page, however fluid.
        XCTAssertLessThanOrEqual(numbers["heightGap"] ?? .infinity, 1, "The editor ended shorter than its words")
    }

    private static let typedInPortuguese = "e depois mais uma linha para ver se a escrita flui bem agora"

    /// "keys=40 keyP95=12.1 …" from the words' label, as numbers.
    private static func probeNumbers(in label: String) -> [String: Double] {
        guard let range = label.range(of: "probe ") else { return [:] }
        return label[range.upperBound...].split(separator: " ").reduce(into: [:]) { numbers, pair in
            let parts = pair.split(separator: "=")
            if parts.count == 2, let value = Double(parts[1]) { numbers[String(parts[0])] = value }
        }
    }

    /// The time, the app's CPU and each step of a letter in the editor (`studio.cue` / Typing).
    private static func typingMetrics(_ app: XCUIApplication) -> [any XCTMetric] {
        let steps: [StaticString] = ["Keystroke", "Edit", "Selection", "Update", "Measure", "Layout"]
        return [XCTClockMetric(), XCTCPUMetric(application: app)]
            + steps.map { XCTOSSignpostMetric(subsystem: "studio.cue", category: "Typing", name: "\($0)") }
    }

    /// The card's idea sent with the stub writing its long script: the page open on its words, ready to type in.
    private func openLongScript() -> XCUIApplication {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestLongScript"])
        let send = app.buttons["ideaCard.submit"]
        XCTAssertTrue(send.exists(within: 15))
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: send)
        waitForExpectations(timeout: 30)
        send.tap()
        let words = app.textViews["page.editor"]
        XCTAssertTrue(words.exists(within: 30), "No page for the long script")
        expectation(for: NSPredicate(format: "isEnabled == true"), evaluatedWith: app.textFields["page.titleField"])
        waitForExpectations(timeout: 30)
        return app
    }
}
