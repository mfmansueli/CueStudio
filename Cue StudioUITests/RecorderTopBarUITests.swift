//
//  RecorderTopBarUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Selfie recorder's top (owner, 11/11/2026): while a take records, the REC pill and the take's number with the time left sit side by
/// side, never over each other or off the screen, with nothing else in the bar; and the text window starts right under the bar's buttons,
/// before and during the take. Run on the smallest and the largest iPhone (`CUE_SIMULATOR`), in Portuguese, in the interface's longest
/// language (Italian) and at the largest text size.
@MainActor
final class RecorderTopBarUITests: XCTestCase {

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testTheRecordingBarFitsAndTheWindowHugsTheButtons() throws {
        continueAfterFailure = false
        let cases: [(language: String, size: String?)] = [
            ("pt", nil), ("it", nil), ("it", "UICTContentSizeCategoryAccessibilityXXXL"),
        ]
        for (language, size) in cases {
            let label = "\(language) · \(size ?? "default size")"
            let app = CueApp.launch(seeded: true, appLanguage: language, contentSize: size, extraArguments: ["-uiTestDemoCamera"])
            let row = app.buttons["row.recordButton"].firstMatch
            XCTAssertTrue(row.exists(within: 15), label)
            row.tap()
            let record = app.buttons["prompter.recordButton"]
            XCTAssertTrue(record.exists(within: 10), label)
            let screen = app.windows.firstMatch.frame
            let text = element(app, "prompter.text")
            let close = app.buttons["prompter.closeButton"]
            XCTAssertTrue(close.exists(within: 5) && text.exists, label)
            let idleGap = text.frame.minY - close.frame.maxY
            XCTAssertTrue((2...14).contains(idleGap), "\(label): the window starts \(idleGap) pt under the bar's buttons")
            keepScreenshot(app, "\(label) · before")
            let idleTop = text.frame.minY

            record.tap()
            let badge = element(app, "prompter.recordingBadge")
            let title = element(app, "prompter.recordingTitle")
            XCTAssertTrue(badge.exists(within: 12) && title.exists(within: 3), label)
            XCTAssertFalse(badge.frame.intersects(title.frame), "\(label): REC \(badge.frame) and the take \(title.frame) overlap")
            XCTAssertGreaterThanOrEqual(badge.frame.minX, screen.minX, label)
            XCTAssertLessThanOrEqual(title.frame.maxX, screen.maxX - 8, "\(label): the take \(title.frame) runs off the screen \(screen)")
            XCTAssertFalse(app.buttons["prompter.aspectButton"].exists, "\(label): nothing else in the bar while recording")
            XCTAssertFalse(close.exists, label)
            XCTAssertEqual(text.frame.minY, idleTop, accuracy: 1, "\(label): the window keeps its top when the take starts")
            let recordingGap = text.frame.minY - max(badge.frame.maxY, title.frame.maxY)
            XCTAssertTrue((0...16).contains(recordingGap), "\(label): the window starts \(recordingGap) pt under REC")
            keepScreenshot(app, "\(label) · recording · \(title.label)")
            app.terminate()
        }
    }

    private func keepScreenshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
