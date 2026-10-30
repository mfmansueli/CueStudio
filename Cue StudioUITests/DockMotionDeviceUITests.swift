//
//  DockMotionDeviceUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Scripts dock's movement on a real iPhone, to film from the Mac (`tools/motion/film.sh`, the iPhone's screen over its cable, as
/// QuickTime does): the writer chip going between Apple Intelligence and Ultra AI, the platform changed under each, and ideas sent with each
/// (the iPhone's own Apple Intelligence and the idea's star in its real time; Ultra AI's stub, its passes held 2 s each so its orbit is seen),
/// and Ultra AI's whole wait round the star at Gemini's pace.
/// In memory and seeded; real animations. Each step prints `CUE-MARK <Unix time> <what>`, which `film.sh` turns into moments of the film.
/// Opt-in: `CUE_DEVICE=… tools/motion/film.sh DockMotionDeviceUITests <folder>` (or `TEST_RUNNER_CUE_MOTION=1 scripts/test.sh device-ui …`).
@MainActor
final class DockMotionDeviceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_MOTION"] != nil else {
            throw XCTSkip("Device film: TEST_RUNNER_CUE_MOTION=1")
        }
    }

    /// Apple Intelligence → Ultra AI and back three times, then the platform changed four times with Ultra AI writing and four with Apple
    /// Intelligence, then "Create for" opened right after each pick: no chip may light but the one picked, and never after a sheet.
    func testFilmingTheWriterAndThePlatform() {
        let app = launch(ai: .stub)
        for _ in 0..<3 {
            pickWriter(app, "Ultra AI")
            pickWriter(app, "Apple Intelligence")
        }
        pickWriter(app, "Ultra AI")
        for platform in ["linkedin", "reels", "youtube", "tiktok"] { pickPlatform(app, platform) }
        pickWriter(app, "Apple Intelligence")
        for platform in ["shorts", "linkedin", "reels", "tiktok"] { pickPlatform(app, platform) }
        for (writer, platform) in [("Ultra AI", "youtube"), ("Apple Intelligence", "linkedin"), ("Ultra AI", "tiktok")] {
            pickWriter(app, writer, settle: false)
            pickPlatform(app, platform)
        }
        XCTAssertTrue(app.buttons["ideaCard.writerChip"].exists)
    }

    /// Four ideas sent with Apple Intelligence (the round star must rise to the middle each time, the first one too, with all a first send
    /// builds), then two with Ultra AI (its ✦, its passes).
    func testFilmingIdeasSent() {
        let app = launch(ai: .appleIntelligence, extra: ["-uiTestStarTransition", "-uiTestUltraSlow"])
        for idea in ["Morning routine for busy parents", "Three tips to film in daylight", "Why I quit coffee", "Packing for a weekend trip"] {
            send(app, idea)
        }
        pickWriter(app, "Ultra AI")
        for idea in ["Street food in Salvador", "How to price a freelance gig"] {
            send(app, idea)
        }
    }

    /// Ultra AI's wait round the star (`UltraWaitScene`), on the iPhone's real clock: the stub thinks as Gemini does and holds the check 22 s
    /// with no words (a chapter's comet), so the film shows the galaxy turning, the moons, the space round the ring and the finish. `gaps.py`
    /// on the film says whether a frame came late while it moves.
    func testFilmingUltraAIsWait() {
        let app = launch(ai: .stub, extra: ["-uiTestStarTransition", "-uiTestUltraPacedLong"])
        pickWriter(app, "Ultra AI")
        send(app, "Why I stopped buying bottled water")
    }

    // MARK: - Steps

    private func launch(ai: CueApp.AIMode, extra: [String] = []) -> XCUIApplication {
        let app = CueApp.launch(seeded: true, ai: ai, animations: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"] + extra)
        mark("launch")
        XCTAssertTrue(app.buttons["ideaCard.submit"].exists(within: 15))
        sleep(2)
        return app
    }

    /// Without `settle`, the next step comes at once (a sheet opened before the chip has turned).
    private func pickWriter(_ app: XCUIApplication, _ writer: String, settle: Bool = true) {
        let chip = app.buttons["ideaCard.writerChip"]
        XCTAssertTrue(chip.exists(within: 5))
        chip.tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", writer)).firstMatch
        XCTAssertTrue(option.exists(within: 5), writer)
        mark("writer → \(writer)")
        option.tap()
        if settle { sleep(3) }
    }

    private func pickPlatform(_ app: XCUIApplication, _ platform: String) {
        app.buttons["ideaCard.platformChip"].tap()
        let row = app.buttons["destination.\(platform)"]
        XCTAssertTrue(row.exists(within: 5), platform)
        mark("platform → \(platform)")
        row.tap()
        sleep(3)
    }

    private func send(_ app: XCUIApplication, _ idea: String) {
        let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
        XCTAssertTrue(field.exists(within: 10))
        field.tap()
        field.typeText(idea)
        mark("send “\(idea)”")
        app.buttons["ideaCard.submit"].tap()
        // The star covers the app from the tap until the page is written (its Cancel is there all the while).
        let star = app.buttons["transition.cancel"]
        XCTAssertTrue(star.exists(within: 4), "No star for “\(idea)”")
        mark("star")
        XCTAssertTrue(star.waitForNonExistence(timeout: 60), "The star stayed for “\(idea)”")
        mark("star gone")
        XCTAssertTrue(app.pageBackButton.exists(within: 5))
        sleep(2)
        mark("back")
        app.pageBackButton.tap()
        sleep(2)
    }

    private func mark(_ what: String) {
        print(String(format: "CUE-MARK %.3f %@", Date().timeIntervalSince1970, what))
    }
}
