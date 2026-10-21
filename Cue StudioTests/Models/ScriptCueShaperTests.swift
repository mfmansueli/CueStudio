//
//  ScriptCueShaperTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("ScriptCueShaper")
struct ScriptCueShaperTests {
    @Test func aScriptWithNoCuesGetsUpToFourAndKeepsEveryWord() {
        let text = "First hook line. More hook.\n\nThe point is here. Another.\n\nTry it out. Follow me."
        let result = ScriptCueShaper.shaped(text)
        #expect(result.added == 4)
        #expect(CueParser.count(in: result.text) == 4)
        #expect(CueParser.stripCues(result.text).replacingOccurrences(of: "  ", with: " ").split(whereSeparator: \.isWhitespace)
            == text.split(whereSeparator: \.isWhitespace))
    }

    @Test func aScriptThatHasCuesIsLeftAlone() {
        let text = "Hook. [pause] Body."
        #expect(ScriptCueShaper.shaped(text) == .init(text: text, added: 0))
    }

    @Test func aShortScriptGetsOnlyWhatFits() {
        let result = ScriptCueShaper.shaped("Just one line here.")
        #expect(result.added == 1)
        #expect(result.text.contains("[pause]"))
        #expect(ScriptCueShaper.shaped("").added == 0)
    }

    @Test func theHooksPauseComesRightAfterTheHook() {
        let result = ScriptCueShaper.shaped("Stop scrolling. Here is why.\n\nBody text. More.")
        #expect(result.text.hasPrefix("Stop scrolling. [pause] Here is why."))
    }
}
