//
//  PCCPrivacyUITests.swift
//  Cue StudioUITests
//

import XCTest

@MainActor
final class PCCPrivacyUITests: XCTestCase {
    func testPrivacyExplainsCloudProcessingAndLocalWritingExamples() throws {
        continueAfterFailure = false
        let app = CueApp.launch(seeded: true)
        let settings = app.cueTabBar.buttons["Settings"]
        XCTAssertTrue(settings.exists(within: 10))
        settings.tap()
        let privacy = app.descendants(matching: .any)["settings.privacy"].firstMatch
        app.scroll(to: privacy)
        privacy.tap()
        let predicate = NSPredicate(format: "label CONTAINS %@", "Your request and voice preferences may be sent to Apple")
        let disclosure = app.staticTexts.matching(predicate).firstMatch
        app.scroll(to: disclosure)
        XCTAssertTrue(disclosure.isHittable)
        XCTAssertTrue(disclosure.label.contains("Writing examples and imported excerpts stay on this iPhone"))
        if let path = ProcessInfo.processInfo.environment["CUE_SCREENSHOT_DIR"] {
            let directory = URL(fileURLWithPath: path, isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try app.screenshot().pngRepresentation.write(to: directory.appending(path: "pcc-privacy.png"))
            try app.debugDescription.write(to: directory.appending(path: "pcc-privacy.txt"), atomically: true, encoding: .utf8)
        }
    }
}
