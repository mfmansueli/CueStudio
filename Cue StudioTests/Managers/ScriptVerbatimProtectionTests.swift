//
//  ScriptVerbatimProtectionTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("Verbatim wording survives cleanup")
struct ScriptVerbatimProtectionTests {
    @Test func cleanupDoesNotChangeWordingTheModelAlreadyKept() {
        let phrase = "Keep  this — exactly."
        let protected = ScriptVerbatimProtection("\(phrase)\n\nAnother sentence.", phrases: [phrase])
        let cleaned = ScriptPromptBuilder.collapsingRepeatedSentences(ScriptPromptBuilder.clean(protected.text))
        #expect(protected.restoring(in: cleaned).contains(phrase))
    }

    @Test func anAbsentPhraseIsNeverInserted() {
        let protected = ScriptVerbatimProtection("Only existing content.", phrases: ["Missing content."])
        #expect(protected.restoring(in: protected.text) == "Only existing content.")
    }
}
