//
//  DraftingAvailabilityUITests.swift
//  Cue StudioUITests
//

import XCTest

/// What Apple Intelligence can't draft is said before any empty draft opens (`-uiTestAIUnavailable`): a Script Language it doesn't write
/// puts the dock in its "Write it" state with the reason; on Auto-detect the idea's language is told when it is sent, the idea stays in the
/// field, and a blank draft opens only when the creator taps "Write it".
@MainActor
final class DraftingAvailabilityUITests: XCTestCase {
    override func setUp() {
        continueAfterFailure = false
    }

    private func element(_ app: XCUIApplication, _ id: String) -> XCUIElement {
        app.descendants(matching: .any)[id].firstMatch
    }

    func testAScriptLanguageTheModelCantDraftInPutsTheDockInWriteIt() {
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestAIUnavailable", "language", "-uiTestScriptLanguage", "th-TH"])
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 15))
        let note = element(app, "generate.unavailableNote")
        XCTAssertTrue(note.exists(within: 5))
        XCTAssertTrue(note.label.contains("Thai"), note.label)
        XCTAssertTrue(note.label.contains("Write it yourself or import a script."), note.label)
        XCTAssertEqual(app.buttons["ideaCard.submit"].label, "Write it")
        XCTAssertFalse(app.buttons["ideaCard.voiceChip"].exists, "Nothing in the dock is violet when it can't draft")
        // "Write it" is the creator's own choice: the idea becomes the title of a blank draft.
        field.tap()
        field.typeText("A day in my life")
        app.buttons["ideaCard.submit"].tap()
        let title = element(app, "page.titleField")
        XCTAssertTrue(title.exists(within: 10))
        XCTAssertEqual(title.value as? String, "A day in my life")
    }

    func testOnAutoAnIdeaTheModelCantDraftSaysWhyAndStaysInTheField() {
        let idea = "ทำไมฉันเลิกกินกาแฟสามสิบวัน"
        let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestAIUnavailable", "language"])
        let field = element(app, "ideaCard.field")
        XCTAssertTrue(field.exists(within: 15))
        XCTAssertFalse(element(app, "generate.unavailableNote").exists, "On Auto-detect nothing is judged before the idea is sent")
        field.tap()
        field.typeText(idea)
        app.buttons["ideaCard.submit"].tap()
        XCTAssertTrue(element(app, "toast").exists(within: 5))
        let reason = app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "can’t draft in Thai")).firstMatch
        XCTAssertTrue(reason.exists, "The toast says why")
        XCTAssertFalse(element(app, "page.editor").exists, "No empty draft opens to say it")
        XCTAssertEqual(field.value as? String, idea)
        // Only "Write it" in the toast makes it a draft to write by hand.
        app.buttons["toast.action"].tap()
        let title = element(app, "page.titleField")
        XCTAssertTrue(title.exists(within: 10))
        XCTAssertEqual(title.value as? String, idea)
    }

    func testEachReasonIsToldInTheDock() {
        let reasons = [
            "device": "This device doesn't support it.",
            "off": "Turn it on in Settings",
            "preparing": "still getting ready",
            "cue": "Privacy & AI data",
        ]
        for (state, words) in reasons.sorted(by: { $0.key < $1.key }) {
            let app = CueApp.launch(seeded: true, extraArguments: ["-uiTestAIUnavailable", state])
            let note = element(app, "generate.unavailableNote")
            XCTAssertTrue(note.exists(within: 15), state)
            XCTAssertTrue(note.label.contains(words), "\(state): \(note.label)")
            XCTAssertEqual(app.buttons["ideaCard.submit"].label, "Write it", state)
            app.terminate()
        }
    }
}
