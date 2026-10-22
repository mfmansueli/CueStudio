//
//  PerformanceDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// How Cue performs on a real iPhone, with XCTest's own metrics: the cold launch, scrolling Scripts over the sky, opening a take
/// in the editor and opening Profile's universe (time, memory, CPU, scroll hitches). In memory and seeded, so the owner's
/// library is never touched; real animations, as a creator sees them. Opt-in (a Debug build: compare runs with each other, not
/// with the App Store's): `CUE_DEVICE=… TEST_RUNNER_CUE_PERF=1 scripts/test.sh device-ui PerformanceDeviceUITests`.
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
}
