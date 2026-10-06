//
//  ScriptCueNameTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("ScriptCueName")
struct ScriptCueNameTests {
    @Test func whatIsTypedBecomesACueName() {
        #expect(ScriptCueName.cleaned("laugh") == "laugh")
        #expect(ScriptCueName.cleaned("  hold   the\nmug  ") == "hold the mug")
        // Brackets would break the tag: they go.
        #expect(ScriptCueName.cleaned("[wink]") == "wink")
    }

    @Test func nothingLeftIsNoCue() {
        #expect(ScriptCueName.cleaned("") == nil)
        #expect(ScriptCueName.cleaned("  [ ] \n") == nil)
    }

    @Test func aLongNameIsCut() {
        let name = ScriptCueName.cleaned(String(repeating: "a", count: 40))
        #expect(name?.count == ScriptCueName.maximumLength)
    }
}
