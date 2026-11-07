//
//  SheetsKeepWorkUITests.swift
//  Cue StudioUITests
//

import XCTest

/// Canvas 2 delivery 3 (owner, 07/11/2026), walked on the glass: no sheet throws work away by accident, and none asks for nothing.
/// - R11 + F14: three picked in Add photo or video, one taken out before confirming, two go in; Cancel with picks asks first,
///   saying how many, and "Keep picking" loses nothing.
/// - R11: Text to speech closed by a swipe keeps the text; Cancel throws it away.
/// - F13: Music and Sound effects are one tall sheet with both parts in sight, each bar button opening its own, and Browse Files
///   right under the search, before Cue's tracks.
@MainActor
final class SheetsKeepWorkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
    }

    private func source(_ name: String) -> XCUIElement { app.segmentedControls["edit.mediaSource"].buttons[name] }

    /// Media › Window › Your library › the three seeded photos, in order.
    private func pickThreeFromTheLibrary() {
        EditorApp.tapTool(app, "addMedia")
        EditorApp.tapTool(app, "mediaWindow")
        XCTAssertTrue(app.buttons["edit.mediaMode.window"].exists(within: 8), "Add photo or video didn't open on Window")
        source("Your library").tap()
        for name in ["Studio wall", "Desk", "Street"] {
            let tile = app.buttons["edit.library.asset.\(name)"]
            XCTAssertTrue(tile.exists(within: 8), "\(name) isn't in the library")
            tile.tap()
        }
        XCTAssertTrue(app.buttons["edit.mediaContinue"].label.contains("3"), "Continue doesn't count 3")
    }

    func testThreePickedOneTakenOutTwoGoIn() {
        app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary"])
        pickThreeFromTheLibrary()
        EditorApp.capture(app, "media-three-picked")
        app.buttons["edit.mediaContinue"].tap()
        let third = app.buttons["edit.mediaRun.remove.3"]
        XCTAssertTrue(third.exists(within: 5), "The review doesn't list three")
        app.buttons["edit.mediaRun.remove.2"].tap()
        XCTAssertTrue(third.isGone(within: 3), "Taking one out left three")
        XCTAssertTrue(app.buttons["edit.mediaRun.remove.2"].exists, "Two should be left, numbered in order")
        EditorApp.capture(app, "media-one-taken-out")
        app.buttons["edit.mediaRun.confirm"].tap()
        XCTAssertTrue(app.buttons["edit.mediaRun.confirm"].isGone(within: 10), "The two never went in")
    }

    func testCancelWithPicksAsksHowManyAndKeepPickingLosesNothing() {
        app = EditorApp.open(demo: true, arguments: ["-uiTestSeedLibrary"])
        pickThreeFromTheLibrary()
        app.buttons["sheet.cancel"].firstMatch.tap()
        let discard = app.buttons["Discard 3"]
        XCTAssertTrue(discard.exists(within: 3), "Cancel with 3 picked didn't ask, or didn't say 3")
        EditorApp.capture(app, "media-discard-question")
        app.buttons["Keep picking"].tap()
        XCTAssertTrue(app.buttons["edit.mediaContinue"].label.contains("3"), "Keep picking lost the picks")
        // A swipe down with picks doesn't throw them away.
        let grabber = app.buttons["Sheet Grabber"].firstMatch
        if grabber.exists {
            grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                .press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
        }
        XCTAssertTrue(app.buttons["edit.mediaContinue"].exists(within: 2), "A swipe down closed the sheet with 3 picked")
        app.buttons["sheet.cancel"].firstMatch.tap()
        app.buttons["Discard 3"].tap()
        XCTAssertTrue(app.buttons["edit.mediaContinue"].isGone(within: 5), "Discard didn't close the sheet")
    }

    func testTextToSpeechKeepsItsTextWhenSwipedAwayAndCancelDiscardsIt() {
        app = EditorApp.open(demo: true)
        openTextToSpeech()
        var text = textField()
        XCTAssertTrue(text.exists(within: 5), "Text to speech didn't open")
        text.tap()
        text.typeText("Three habits that changed my mornings.")
        // Closed by accident: the sheet dragged down by its grabber (the first drag may only put the keyboard away).
        for _ in 0..<2 where text.exists {
            let grabber = app.buttons["Sheet Grabber"].firstMatch
            let from = grabber.exists ? grabber.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
                : app.staticTexts["Text to speech"].firstMatch.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
            from.press(forDuration: 0.1, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.98)))
            _ = text.isGone(within: 2)
        }
        XCTAssertTrue(text.isGone(within: 5), "The sheet didn't close by a swipe")
        openTextToSpeech()
        text = textField()
        XCTAssertTrue(text.exists(within: 5))
        XCTAssertEqual(text.value as? String, "Three habits that changed my mornings.", "The text didn't come back")
        XCTAssertTrue(app.staticTexts["Your text from before is back · Cancel discards it"].exists, "Nothing says the text came back")
        EditorApp.capture(app, "tts-draft-back")
        app.buttons["sheet.cancel"].firstMatch.tap()
        XCTAssertTrue(text.isGone(within: 5))
        openTextToSpeech()
        text = textField()
        XCTAssertTrue(text.exists(within: 5))
        XCTAssertNotEqual(text.value as? String, "Three habits that changed my mornings.", "Cancel kept the text")
    }

    func testMusicAndSoundEffectsAreOneTallSheetWithBothPartsInSight() {
        app = EditorApp.open(demo: true)
        EditorApp.tapTool(app, "audio")
        EditorApp.tapTool(app, "soundEffects")
        let parts = app.segmentedControls["edit.addSoundPart"]
        XCTAssertTrue(parts.exists(within: 5), "Sound effects opened without the two parts")
        XCTAssertTrue(parts.buttons["Sound effects"].isSelected, "The bar's Sound effects didn't open its own part")
        // Between the two parts and the effects' groups, no second "Sound effects" (the bar's button behind the sheet doesn't count).
        let groups = app.descendants(matching: .any)["edit.effectGroup.all"]
        XCTAssertTrue(groups.exists(within: 3))
        let named = app.staticTexts.matching(identifier: "Sound effects").allElementsBoundByIndex
        XCTAssertFalse(named.contains { $0.frame.midY > parts.frame.maxY && $0.frame.midY < groups.frame.minY }, "The part's name is said twice")
        let sheetTop = parts.frame.minY
        XCTAssertLessThan(sheetTop, app.frame.height * 0.25, "The sheet isn't tall: its parts are at \(sheetTop)")
        EditorApp.capture(app, "sound-effects-tall")
        parts.buttons["Music"].tap()
        let files = app.buttons["edit.addMusicButton"]
        let search = app.descendants(matching: .any)["edit.library.search"]
        XCTAssertTrue(files.exists(within: 3) && files.isHittable, "Browse Files isn't in sight under the search")
        XCTAssertLessThan(search.frame.maxY, files.frame.minY)
        XCTAssertLessThan(files.frame.maxY, app.buttons["edit.library.play.morningNotes"].frame.minY, "Browse Files isn't before Cue's tracks")
        EditorApp.capture(app, "music-files-first")
    }

    /// Audio › Text to speech; the bar stays on Audio after the sheet closes.
    private func openTextToSpeech() {
        if !app.buttons["edit.toolbar.textToSpeech"].exists(within: 2) { EditorApp.tapTool(app, "audio") }
        EditorApp.tapTool(app, "textToSpeech")
    }

    private func textField() -> XCUIElement {
        app.textFields["tts.text"].firstMatch.exists(within: 2) ? app.textFields["tts.text"] : app.textViews["tts.text"]
    }
}
