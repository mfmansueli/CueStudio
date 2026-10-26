//
//  PerformanceDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// How Cue performs on a real iPhone, with XCTest's own metrics: the cold launch, scrolling Scripts over the sky, opening a take
/// in the editor, opening Profile's universe, the idea's star and the Logbook (time, memory, CPU, scroll and animation hitches). In
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

    /// The Logbook as a creator uses it, every movement real: the sheet comes up, typing (the microphone steps aside), two ideas saved,
    /// the keyboard swiped away (the microphone comes back), one idea swiped away, the other picked with Select and deleted, the sheet
    /// closed. It ends as it began (an empty Logbook), so each run is the same. Hitches while the capture folds and unfolds ("Logbook fold").
    func testUsingTheLogbook() {
        let app = CueApp.launch(seeded: true, animations: true)
        let open = app.buttons["scripts.logbookButton"]
        XCTAssertTrue(open.exists(within: 15))
        let field = app.descendants(matching: .any)["logbook.field"].firstMatch
        let entries = app.descendants(matching: .any).matching(identifier: "logbook.entry")
        // XCTest runs the block on the main thread.
        let fold = XCTOSSignpostMetric(subsystem: "studio.cue", category: "Motion", name: "Logbook fold")
        // Its hitches, over the fold of the capture each way (XCTest's own `XCTHitchMetric` read none, even where these found some).
        measure(metrics: [fold], options: options) {
            MainActor.assumeIsolated {
                open.tap()
                XCTAssertTrue(field.exists(within: 5))
                // Where a finger would: an element's own tap scrolls the list to it first, which no finger does.
                field.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
                field.typeText("Slow mornings\n")
                field.typeText("Tiny desk setups\n")
                XCTAssertTrue(entries.element(boundBy: 1).exists(within: 5))
                // Down on the list (the keyboard follows the finger away), not on the sheet, which would be dragged.
                entries.element(boundBy: 0).swipeDown(velocity: .slow)
                entries.element(boundBy: 1).swipeLeft()
                app.buttons["Delete"].tap()
                app.buttons["logbook.selectButton"].tap()
                entries.element(boundBy: 0).tap()
                app.buttons["logbook.deleteSelectionButton"].tap()
                XCTAssertTrue(app.descendants(matching: .any)["logbook.empty"].firstMatch.exists(within: 5))
                app.navigationBars.buttons["logbook.doneButton"].tap()
                XCTAssertTrue(open.exists(within: 5))
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
}
