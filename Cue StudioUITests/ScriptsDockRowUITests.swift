//
//  ScriptsDockRowUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Scripts dock's first row: Format, the platform, the voice, the writer and Find inspiration. Opt-in pictures of it for choosing its
/// layout (`TEST_RUNNER_CUE_SCREENSHOT_DIR=<folder>`), with each chip's frame.
@MainActor
final class ScriptsDockRowUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private static let row = ["ideaCard.formatChip", "ideaCard.platformChip", "ideaCard.voiceChip", "ideaCard.writerChip", "ideaCard.inspirationButton"]

    /// Format, the platform, the voice, the writer and the lightbulb are all seen at once, with Apple Intelligence and with Ultra AI writing:
    /// nothing is past the dock's edge for a scroll to reach.
    func testTheWholeRowIsSeenWithoutScrolling() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"])
        XCTAssertTrue(app.buttons["ideaCard.submit"].exists(within: 15))
        func expectWholeRow(_ state: String) {
            let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
            let bulb = app.buttons["ideaCard.inspirationButton"]
            XCTAssertTrue(bulb.exists(within: 5))
            for id in Self.row.dropLast() {
                let chip = app.descendants(matching: .any)[id].firstMatch
                XCTAssertTrue(chip.exists, "\(id) is missing (\(state))")
                // The chips start where the field does and end before the lightbulb.
                XCTAssertGreaterThanOrEqual(chip.frame.minX, field.frame.minX - 16, "\(id) is cut at the start (\(state)): \(chip.frame)")
                XCTAssertLessThanOrEqual(chip.frame.maxX, bulb.frame.minX + 4, "\(id) runs under the lightbulb (\(state)): \(chip.frame)")
            }
        }
        expectWholeRow("Apple Intelligence")
        app.buttons["ideaCard.writerChip"].tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ultra AI")).firstMatch
        XCTAssertTrue(option.exists(within: 5))
        option.tap()
        let chip = app.buttons["ideaCard.writerChip"]
        XCTAssertTrue(chip.matches(NSPredicate(format: "label CONTAINS %@", "Ultra AI"), within: 5))
        expectWholeRow("Ultra AI")
    }

    func testCaptureTheDockRow() throws {
        guard let path = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] else { throw XCTSkip("Set TEST_RUNNER_CUE_SCREENSHOT_DIR to capture") }
        let folder = URL(fileURLWithPath: path, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestUltra", "-uiTestUltraAllowed"])
        XCTAssertTrue(app.buttons["ideaCard.submit"].exists(within: 15))
        func shot(_ name: String) throws {
            sleep(1)
            try app.screenshot().pngRepresentation.write(to: folder.appending(path: "\(name).png"))
            var frames = ["window": "\(app.windows.firstMatch.frame)"]
            for id in Self.row {
                let element = app.descendants(matching: .any)[id].firstMatch
                frames[id] = element.exists ? "\(element.frame) label=\(element.label)" : "absent"
            }
            let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
            frames["ideaCard.field"] = "\(field.frame)"
            let data = try JSONSerialization.data(withJSONObject: frames, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: folder.appending(path: "\(name).json"))
        }
        try shot("dock-apple")
        app.buttons["ideaCard.writerChip"].tap()
        let option = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Ultra AI")).firstMatch
        XCTAssertTrue(option.exists(within: 5))
        option.tap()
        try shot("dock-ultra")
    }
}
