//
//  ScriptTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("Script")
struct ScriptTests {
    @Test func shareTextIsTheTitleThenTheScript() {
        let script = TestData.script(title: "Morning habits", text: "Okay, real talk. [pause]\n\nNumber one.")
        #expect(script.shareText == "Morning habits\n\nOkay, real talk. [pause]\n\nNumber one.")
    }

    @Test func untitledScriptsShareWithThePlaceholderTitle() {
        let script = TestData.script(title: "  ", text: "Hello.")
        #expect(script.shareText == "Untitled script\n\nHello.")
    }

    @Test func v1ScriptsOpenWithoutAFactCheck() throws {
        let v1 = """
        {"id":"00000000-0000-0000-0000-000000000009","title":"Old","text":"Hi.","platform":"tiktok",
         "version":2,"createdAt":"2026-09-01T10:00:00Z","updatedAt":"2026-09-02T10:00:00Z"}
        """
        let script = try JSONDecoder.library.decode(Script.self, from: Data(v1.utf8))
        #expect(script.version == 2)
        #expect(!script.factCheck)
        #expect(script.type == nil)
    }

    @Test func factCheckSurvivesSaving() throws {
        var script = TestData.script()
        script.factCheck = true
        let decoded = try JSONDecoder.library.decode(Script.self, from: JSONEncoder.library.encode(script))
        #expect(decoded.factCheck)
    }

    @Test func previewLineSkipsCues() {
        let script = TestData.script(text: "[confident] Okay, real talk. [pause]\n\nSecond paragraph.")
        #expect(script.previewLine == "Okay, real talk.")
    }
}
