import XCTest

/// Real model, real card and inspiration handoff; in-memory data protects the creator's library.
/// Only opt in on a physical iPhone: TEST_RUNNER_CUE_DURATION_UI=1.
@MainActor
final class RealScriptDurationDeviceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
        guard ProcessInfo.processInfo.environment["CUE_DURATION_UI"] == "1" else {
            throw XCTSkip("Opt-in real-device AI UI test")
        }
    }

    private var policy: String { ProcessInfo.processInfo.environment["CUE_DURATION_UI_POLICY"] ?? "informative" }

    private func launch() -> XCUIApplication {
        var arguments = ["-uiTestPCCGeneration", "-uiTestScriptLanguage", "pt-BR", "-uiTestTopics", "custom:Gravação com luz natural"]
        if policy == "informative" { arguments.append("-uiTestInformativeDuration") }
        let app = CueApp.launch(seeded: true, pro: true, ai: .appleIntelligence, appLanguage: "en", extraArguments: arguments)
        if app.pageBackButton.exists(within: 3) { app.pageBackButton.tap() }
        let scripts = app.cueTabBar.buttons["Scripts"]
        if scripts.exists { scripts.tap() }
        return app
    }

    func testGenerateFromTheActualScriptCard() throws {
        let app = launch()
        let prompt = "Explique três ajustes para gravar com uma janela. Dê um jeito de conferir cada um. Sem pedir para seguir."
        let field = app.descendants(matching: .any)["ideaCard.field"].firstMatch
        XCTAssertTrue(field.exists(within: 20))
        field.tap()
        field.typeText(prompt)
        app.buttons["ideaCard.submit"].tap()
        let text = try finishedText(in: app)
        try keep(app, fields: ["entry": "script-card", "prompt": prompt, "text": text])
    }

    func testGenerateFromTheActualFindInspirationAngle() throws {
        let app = launch()
        let ideas = app.buttons["ideaCard.inspirationButton"]
        XCTAssertTrue(ideas.exists(within: 20))
        ideas.tap()
        let angle = app.descendants(matching: .any)["inspiration.card.angle"].firstMatch
        XCTAssertTrue(angle.exists(within: 90), "A real angle must arrive; a starter title alone is not this test")
        let title = app.descendants(matching: .any)["inspiration.card.title"].firstMatch.label
        let angleText = angle.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n")
        let opening = app.descendants(matching: .any)["inspiration.card.opening"].firstMatch
        let openingText = opening.exists ? opening.staticTexts.allElementsBoundByIndex.map(\.label).joined(separator: "\n") : ""
        let write = app.buttons["inspiration.writeNow"]
        app.scroll(to: write)
        write.tap()
        let text = try finishedText(in: app)
        try keep(app, fields: ["entry": "find-inspiration", "subject": title, "angle": angleText, "opening": openingText, "text": text])
    }

    private func finishedText(in app: XCUIApplication) throws -> String {
        let editor = app.descendants(matching: .any)["page.editor"].firstMatch
        let complete = NSPredicate { _, _ in
            editor.exists && (editor.value as? String ?? "").count > 80 && !app.buttons["page.stopButton"].exists
        }
        let waited = XCTWaiter.wait(for: [expectation(for: complete, evaluatedWith: nil)], timeout: 150)
        XCTAssertEqual(waited, .completed, "Real AI must finish on the script page")
        return try XCTUnwrap(editor.value as? String)
    }

    private func keep(_ app: XCUIApplication, fields: [String: String]) throws {
        var fields = fields
        fields["durationPolicy"] = policy
        fields["model"] = "Real Apple Intelligence; PCC preferred, actual route not observed by this UI test"
        fields["qualityStatus"] = "Requires review of the recorded output, not approved by UI navigation"
        let data = try JSONSerialization.data(withJSONObject: fields, options: [.prettyPrinted, .sortedKeys])
        let attachment = XCTAttachment(data: data, uniformTypeIdentifier: "public.json")
        attachment.name = "real-script-ui-\(policy)-\(fields["entry"] ?? "flow").json"
        attachment.lifetime = .keepAlways
        add(attachment)
        let screenshot = XCTAttachment(screenshot: app.screenshot())
        screenshot.lifetime = .keepAlways
        add(screenshot)
    }
}
