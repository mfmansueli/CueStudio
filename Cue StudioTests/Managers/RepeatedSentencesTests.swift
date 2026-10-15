//
//  RepeatedSentencesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A sentence the model says again word for word goes after the first time (`ScriptPromptBuilder.collapsingRepeatedSentences`): the loop of the
/// `after-2` device run, and nothing of the scripts the model wrote well.
@MainActor
@Suite("Repeated sentences")
struct RepeatedSentencesTests {
    @Test func aLoopKeepsEachSentenceOnce() {
        let loop = "Hola, familia. [smile] Esa es nuestra esencia. [mirar cámara] Esa es nuestra misión. [mirar cámara] Esa es nuestra esencia. "
            + "[mirar cámara] Esa es nuestra misión. [mirar cámara] Esa es nuestra esencia. [mirar cámara]"
        let kept = ScriptPromptBuilder.collapsingRepeatedSentences(loop)
        #expect(kept == "Hola, familia. [smile] Esa es nuestra esencia. [mirar cámara] Esa es nuestra misión. [mirar cámara]")
    }

    @Test func shortLinesAndParagraphsStay() {
        let text = "Save this. Try it tonight.\n\nTell me how it went. Save this."
        #expect(ScriptPromptBuilder.collapsingRepeatedSentences(text) == text)
    }

    @Test func aSentenceRepeatedInALaterBlockGoes() {
        let text = "Drink water when you wake up.\n\nThen stretch for two minutes. Drink water when you wake up.\n\nSave this."
        #expect(ScriptPromptBuilder.collapsingRepeatedSentences(text) == "Drink water when you wake up.\n\nThen stretch for two minutes.\n\nSave this.")
    }

    @Test func theDeviceRunsLoseNothingButTheLoop() throws {
        var changed: [String] = []
        for run in ["baseline-a", "after-1", "after-2"] {
            for sample in try QualityRunFixture.samples(run) where sample.kind == "script" {
                guard let text = sample.text, ScriptPromptBuilder.collapsingRepeatedSentences(text) != text else { continue }
                changed.append("\(run) \(sample.language)-\(sample.condition)[\(sample.index)]")
            }
        }
        // The loop of after-2, and two scripts that said one sentence twice (pt-BR "Fala, galera!" again at the end has fewer than three words and stays).
        #expect(changed.contains("after-2 es-ES-half[1]"))
        print("REPEATED SENTENCES removed in: \(changed)")
        #expect(changed.count <= 4, "\(changed)")
    }
}
