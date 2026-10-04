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

        XCTAssertTrue(app.buttons["newScript.write"].waitForExistence(timeout: 5))
    }

    func testPlusOffersWriteMyOwnAndImportOnly() {
        let app = CueApp.launch(seeded: true)
        let plus = app.buttons["scripts.newButton"]
        XCTAssertTrue(plus.waitForExistence(timeout: 15))
        plus.tap()

        // The AI lives in the idea card, not in this sheet.
        XCTAssertTrue(app.buttons["newScript.write"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["newScript.import"].exists)
        for gone in ["newScript.prompt", "newScript.themes", "newScript.formats"] {
            XCTAssertFalse(app.buttons[gone].exists, "\(gone) is gone")
        }
        app.buttons["newScript.write"].tap()
        XCTAssertTrue(app.descendants(matching: .any)["page.draftEditor"].waitForExistence(timeout: 5))
    }

    func testWritingAnIdeaOpensItOnThePage() {
        let app = CueApp.launch(seeded: true)
        let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 15))
        field.tap()
        field.typeText("3 tips for better lighting")
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(app.buttons["page.backButton"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.descendants(matching: .any)["page.draftEditor"].waitForExistence(timeout: 10))
    }
}
