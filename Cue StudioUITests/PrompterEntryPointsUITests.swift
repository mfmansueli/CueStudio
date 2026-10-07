//
//  PrompterEntryPointsUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Every way to record opens the same prompter: the one the camera button of the tab bar opens (Selfie: the front camera behind the text window, the
/// aspect button, the play button and the display button). Studio mode is the one other prompter, and only its own menu entry opens it.
@MainActor
final class PrompterEntryPointsUITests: XCTestCase {
    private static let ready = "Oat & Co. — sponsored read"

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    /// The Selfie prompter's own controls are there, and Studio's marker is not. Without a script the panel offers "Add script" instead of play.
    private func assertSelfiePrompter(
        _ app: XCUIApplication, _ path: String, hasScript: Bool = true, file: StaticString = #filePath, line: UInt = #line
    ) {
        XCTAssertTrue(app.buttons["prompter.closeButton"].waitForExistence(timeout: 15), "\(path): no prompter", file: file, line: line)
        XCTAssertTrue(element(app, "prompter.aspectButton").waitForExistence(timeout: 5), "\(path): not the Selfie prompter", file: file, line: line)
        if hasScript {
            XCTAssertTrue(element(app, "prompter.playButton").exists, "\(path): no play button", file: file, line: line)
            XCTAssertTrue(element(app, "prompter.displayButton").exists, "\(path): no display button", file: file, line: line)
        } else {
            XCTAssertTrue(element(app, "prompter.addScriptButton").exists, "\(path): no Add script", file: file, line: line)
        }
        XCTAssertFalse(element(app, "prompter.remoteButton").exists, "\(path): opened Studio", file: file, line: line)
    }

    func testTheCameraButtonOpensSelfieWithTheScriptYouPick() throws {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.tabBars.buttons["Record"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Record"].tap()
        let recent = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH 'startRecording.recent.'")).firstMatch
        XCTAssertTrue(recent.waitForExistence(timeout: 5))
        recent.tap()
        assertSelfiePrompter(app, "camera button › script")
    }

    func testTheCameraButtonWithoutAScriptOpensTheSameSelfie() throws {
        let app = CueApp.launch(seeded: true)
        XCTAssertTrue(app.tabBars.buttons["Record"].waitForExistence(timeout: 15))
        app.tabBars.buttons["Record"].tap()
        let skip = app.buttons["startRecording.skip"]
        XCTAssertTrue(skip.waitForExistence(timeout: 5))
        skip.tap()
        assertSelfiePrompter(app, "camera button › without a script", hasScript: false)
    }

    func testRecordOnTheScriptPageOpensTheSameSelfie() throws {
        let app = CueApp.launch(seeded: true)
        app.openScriptPage(titled: Self.ready)
        let record = app.buttons["detail.recordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        record.tap()
        assertSelfiePrompter(app, "script page › Record")
    }

    func testRecordInARowsMenuOpensTheSameSelfie() throws {
        let app = CueApp.launch(seeded: true)
        app.scriptRow(Self.ready).press(forDuration: 1.2)
        // The tab bar has a "Record" too: the menu's is the one above it.
        let tabBar = app.tabBars.firstMatch
        XCTAssertTrue(app.buttons["Studio mode"].waitForExistence(timeout: 5), "The row's menu didn't open")
        let record = app.buttons.matching(identifier: "Record").allElementsBoundByIndex.first { !$0.frame.intersects(tabBar.frame) }
        try XCTUnwrap(record).tap()
        assertSelfiePrompter(app, "script row › Record")
    }

    func testOnlyStudioModeOpensTheStudioPrompter() throws {
        let app = CueApp.launch(seeded: true)
        app.openStudio(titled: Self.ready)
        XCTAssertTrue(element(app, "prompter.remoteButton").waitForExistence(timeout: 15))
        XCTAssertFalse(element(app, "prompter.aspectButton").exists, "Studio has no camera frame")
    }
}
