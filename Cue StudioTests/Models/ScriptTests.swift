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

    @Test func previewLineSkipsCues() {
        let script = TestData.script(text: "[confident] Okay, real talk. [pause]\n\nSecond paragraph.")
        #expect(script.previewLine == "Okay, real talk.")
    }
}
