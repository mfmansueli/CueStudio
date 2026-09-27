//
//  CreateScriptUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The record button and the ways to create a script.
@MainActor
final class CreateScriptUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testRecordTabAsksWhatYouAreRecording() {
        let app = CueApp.launch(seeded: true)
        let recordTab = app.tabBars.buttons["Record"]
        XCTAssertTrue(recordTab.waitForExistence(timeout: 15))
        recordTab.tap()

        XCTAssertTrue(app.buttons["newScript.write"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["newScript.generate"].exists)
        app.buttons["newScript.skip"].tap()
        XCTAssertTrue(app.buttons["prompter.addScriptButton"].waitForExistence(timeout: 5))
        app.buttons["prompter.closeButton"].tap()
    }

    func testGeneratingAScriptOpensItInTheEditor() {
        let app = CueApp.launch(seeded: true)
        let plus = app.buttons["scripts.plusMenu"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()
        app.buttons["Generate with AI"].tap()

        let list = app.buttons["generate.type.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.tap()
        let generate = app.buttons["generate.generateButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()

        // The on-device model can take a while on first use.
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 90))
    }
}
