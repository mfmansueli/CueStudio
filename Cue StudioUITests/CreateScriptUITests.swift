//
//  CreateScriptUITests.swift
//  Cue StudioUITests
//

import XCTest

/// The Record tab, the "+" button and the ways to create a script.
@MainActor
final class CreateScriptUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    func testRecordTabOffersRecentScriptsAndFreestyle() {
        let app = CueApp.launch(seeded: true)
        let recordTab = app.tabBars.buttons["Record"]
        XCTAssertTrue(recordTab.waitForExistence(timeout: 15))
        recordTab.tap()

        XCTAssertTrue(app.staticTexts["Read from a script"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["startRecording.newScript"].exists)
        app.buttons["startRecording.skip"].tap()
        XCTAssertTrue(app.buttons["prompter.addScriptButton"].waitForExistence(timeout: 5))
        app.buttons["prompter.closeButton"].tap()
        // Record never becomes the selected tab.
        XCTAssertTrue(app.tabBars.buttons["Scripts"].isSelected)
    }

    func testRecordTabLeadsToNewScript() {
        let app = CueApp.launch(seeded: true)
        let recordTab = app.tabBars.buttons["Record"]
        XCTAssertTrue(recordTab.waitForExistence(timeout: 15))
        recordTab.tap()
        let newScript = app.buttons["startRecording.newScript"]
        XCTAssertTrue(newScript.waitForExistence(timeout: 5))
        newScript.tap()

        XCTAssertTrue(app.buttons["newScript.prompt"].waitForExistence(timeout: 5))
    }

    func testPlusOffersEveryWayToStartAScript() {
        let app = CueApp.launch(seeded: true)
        let plus = app.buttons["scripts.newButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()

        XCTAssertTrue(app.buttons["newScript.prompt"].waitForExistence(timeout: 5))
        for tile in ["newScript.write", "newScript.import", "newScript.themes", "newScript.formats"] {
            XCTAssertTrue(app.buttons[tile].exists, "Missing \(tile)")
        }
        app.buttons["newScript.write"].tap()
        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 5))
    }

    func testGeneratingAScriptOpensItInTheEditor() {
        let app = CueApp.launch(seeded: true)
        let plus = app.buttons["scripts.newButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()
        let formats = app.buttons["newScript.formats"]
        XCTAssertTrue(formats.waitForExistence(timeout: 5))
        formats.tap()

        let list = app.buttons["generate.type.list"]
        XCTAssertTrue(list.waitForExistence(timeout: 5))
        list.tap()
        let generate = app.buttons["generate.generateButton"]
        XCTAssertTrue(generate.waitForExistence(timeout: 5))
        generate.tap()

        XCTAssertTrue(app.buttons["editor.doneButton"].waitForExistence(timeout: 10))
    }
}
