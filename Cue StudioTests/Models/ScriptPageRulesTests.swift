//
//  ScriptPageRulesTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("Script page rules")
struct ScriptPageRulesTests {
    @Test func doneWithNoTextSavesNothing() {
        #expect(ScriptPageRules.done(text: "  \n ", type: .tutorial) == .nothingToSave)
    }

    @Test func aFormatWithEmptySectionsAsksAndAScriptWithNoFormatDoesNot() {
        #expect(ScriptPageRules.done(text: "Hook only.", type: .tutorial) == .confirmEmptySections(3))
        #expect(ScriptPageRules.done(text: "Hook only.", type: nil) == .finish)
        #expect(ScriptPageRules.done(text: "One.\n\nTwo.\n\nThree.\n\nFour.", type: .tutorial) == .finish)
    }

    @Test func emptySectionsAreTheFormatsSectionsMinusTheParagraphsWritten() {
        #expect(ScriptPageRules.emptySections(text: "A.\n\nB.", type: .pov) == 1)
        #expect(ScriptPageRules.emptySections(text: "A.\n\nB.\n\nC.\n\nD.\n\nE.", type: .pov) == 0)
    }
}
