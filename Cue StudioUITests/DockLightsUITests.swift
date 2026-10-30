//
//  DockLightsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Scripts dock's lights, counted by the app (`-uiTestDockMotionLog`) instead of filmed: a network picked lights only the network's
/// chip, a writer picked only the writer's (and Ultra AI's charges the send arrow), a writer picked just before a sheet opens never lights
/// on its own as the sheet goes (the owner saw Ultra AI light up with a network, 29/10/2026), and every idea sent has its star. Real
/// animations, stub writers.
@MainActor
final class DockLightsUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    /// What `dock.motionLog` says: how many times each light has gone, and who the chip and the arrow show.
    private struct Lights: Equatable, CustomStringConvertible {
        var ultra = 0
        var apple = 0
        var platform = 0
        var send = 0
        var chip = ""
        var arrow = ""

        var description: String { "ultra \(ultra), apple \(apple), platform \(platform), send \(send), chip \(chip), arrow \(arrow)" }
    }

    func testEachPickLightsOnlyItsOwnChip() {
        let app = launch()
        var expected = lights(app)
        XCTAssertEqual(expected, Lights(chip: "apple", arrow: "apple"))

        pickWriter(app, "Ultra AI")
        expected.ultra += 1
        expected.send += 1
        expected.chip = "ultra"
        expected.arrow = "ultra"
        expectLights(app, expected, "Ultra AI picked")
        for platform in ["linkedin", "reels", "youtube"] {
            pickPlatform(app, platform)
            expected.platform += 1
            expectLights(app, expected, "\(platform) picked with Ultra AI")
        }

        pickWriter(app, "Apple Intelligence")
        expected.apple += 1
        expected.chip = "apple"
        expected.arrow = "apple"
        expectLights(app, expected, "Apple Intelligence picked")
        for platform in ["shorts", "linkedin", "tiktok"] {
            pickPlatform(app, platform)
            expected.platform += 1
            expectLights(app, expected, "\(platform) picked with Apple Intelligence")
        }
    }

    func testAWriterPickedJustBeforeASheetNeverLightsAsItGoes() {
        let app = launch()
        for (writer, platform, shown) in [("Ultra AI", "linkedin", "ultra"), ("Apple Intelligence", "reels", "apple"), ("Ultra AI", "youtube", "ultra")] {
            pickWriter(app, writer)
            // "Create for" at once, as the writer's menu closes.
            app.buttons["ideaCard.platformChip"].tap()
            let row = app.buttons["destination.\(platform)"]
            XCTAssertTrue(row.exists(within: 5), platform)
            row.tap()
            XCTAssertTrue(row.waitForNonExistence(timeout: 5))
            let asItGoes = lights(app)
            sleep(3)
            let after = lights(app)
            XCTAssertEqual(after.ultra, asItGoes.ultra, "Ultra AI lit after the sheet (\(writer), \(platform)): \(asItGoes) → \(after)")
            XCTAssertEqual(after.apple, asItGoes.apple, "Apple Intelligence lit after the sheet (\(writer), \(platform)): \(asItGoes) → \(after)")
            XCTAssertEqual(after.chip, shown, "The chip doesn't show \(writer)")
            XCTAssertEqual(after.arrow, shown, "The arrow doesn't show \(writer)")
        }
    }

    func testEveryIdeaSentHasItsStar() {
        let app = launch(extra: ["-uiTestStarTransition"])
        for idea in ["Morning routine for busy parents", "Three tips to film in daylight"] { send(app, idea) }
        pickWriter(app, "Ultra AI")
        sleep(2)
        send(app, "Street food in Salvador")
    }

    // MARK: - Steps

    private func launch(extra: [String] = []) -> XCUIApplication {
        let app = CueApp.launch(
            seeded: true, animations: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed", "-uiTestDockMotionLog"] + extra
        )
        XCTAssertTrue(app.buttons["ideaCard.writerChip"].exists(within: 15))
        XCTAssertTrue(app.descendants(matching: .any)["dock.motionLog"].exists(within: 5))
        return app
    }

    private func lights(_ app: XCUIApplication) -> Lights {
        var lights = Lights()
        for pair in app.descendants(matching: .any)["dock.motionLog"].label.split(separator: " ") {
            let parts = pair.split(separator: "=").map(String.init)
            guard parts.count == 2 else { continue }
            switch parts[0] {
            case "ultra": lights.ultra = Int(parts[1]) ?? -1
            case "apple": lights.apple = Int(parts[1]) ?? -1
            case "platform": lights.platform = Int(parts[1]) ?? -1
            case "send": lights.send = Int(parts[1]) ?? -1
            case "chip": lights.chip = parts[1]
            case "arrow": lights.arrow = parts[1]
            default: break
            }
        }
        return lights
    }

    /// The lights come to `expected` within 4 s, and nothing else lights in the second after.
    private func expectLights(
        _ app: XCUIApplication, _ expected: Lights, _ what: String, file: StaticString = #filePath, line: UInt = #line
    ) {
        let deadline = Date().addingTimeInterval(4)
        var now = lights(app)
        while now != expected, Date() < deadline {
            usleep(200_000)
            now = lights(app)
        }
        XCTAssertEqual(now, expected, what, file: file, line: line)
        sleep(1)
        XCTAssertEqual(lights(app), expected, "\(what): something lit after", file: file, line: line)
    }

    private func pickWriter(_ app: XCUIApplication, _ writer: String) {
        app.buttons["ideaCard.writerChip"].tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", writer)).firstMatch
        XCTAssertTrue(option.exists(within: 5), writer)
        option.tap()
    }

    private func pickPlatform(_ app: XCUIApplication, _ platform: String) {
        app.buttons["ideaCard.platformChip"].tap()
        let row = app.buttons["destination.\(platform)"]
        XCTAssertTrue(row.exists(within: 5), platform)
        row.tap()
    }

    /// The star covers the app from the tap until the page is written (its Cancel is there all the while), then the page is left.
    private func send(_ app: XCUIApplication, _ idea: String) {
        let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
        XCTAssertTrue(field.exists(within: 10))
        field.tap()
        field.typeText(idea)
        app.buttons["ideaCard.submit"].tap()
        let star = app.buttons["transition.cancel"]
        XCTAssertTrue(star.exists(within: 4), "No star for “\(idea)”")
        XCTAssertTrue(star.waitForNonExistence(timeout: 30), "The star stayed for “\(idea)”")
        XCTAssertTrue(app.pageBackButton.exists(within: 5))
        app.pageBackButton.tap()
        XCTAssertTrue(app.buttons["ideaCard.submit"].exists(within: 5))
        sleep(1)
    }
}
