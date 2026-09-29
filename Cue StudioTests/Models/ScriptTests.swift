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
        // Saved before scripts had a language: Auto-detect, text untouched.
        #expect(script.language == nil)
        #expect(script.text == "Hi.")
    }

    @Test func theLanguageIsSavedWithTheScript() throws {
        let script = TestData.script(text: "Oi, gente!", language: .portugueseBrazil)
        let data = try JSONEncoder.library.encode(script)
        #expect(String(decoding: data, as: UTF8.self).contains(#""language":"pt-BR""#))
        let decoded = try JSONDecoder.library.decode(Script.self, from: data)
        #expect(decoded.language == .portugueseBrazil)
        #expect(decoded.text == "Oi, gente!")
    }

    @Test func aLanguageFromANewerBuildReadsAsAutoDetect() throws {
        let saved = #"{"id":"00000000-0000-0000-0000-000000000009","title":"Nuevo","text":"Hola.","platform":"tiktok","language":"xx-XX"}"#
        let script = try JSONDecoder.library.decode(Script.self, from: Data(saved.utf8))
        #expect(script.language == nil)
        #expect(script.text == "Hola.")
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
