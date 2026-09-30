//
//  CaptionTranslationBuilderTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Translating captions sentence by sentence and breaking the result back into lines, keeping the
/// creator's corrections and noticing when the original changes.
@Suite("Caption translation builder")
struct CaptionTranslationBuilderTests {
    private func cue(_ text: String, _ start: Double, _ end: Double, source: UUID? = nil) -> CaptionCue {
        var cue = CaptionCue(text: text, start: start, end: end)
        cue.sourceID = source
        return cue
    }

    @Test func sentencesEndAtPunctuationPausesAndOtherRecordings() {
        let other = UUID()
        let captions = [
            cue("Hoje vou mostrar", 0, 1), cue("duas ferramentas.", 1.1, 2),
            cue("A primeira", 2.1, 3), cue("é simples", 4.5, 5.5),
            cue("Outra gravação", 0, 1, source: other),
        ]
        let sentences = CaptionTranslationBuilder.sentences(from: captions)
        #expect(sentences.map { CaptionTranslationBuilder.text(of: $0) } == [
            "Hoje vou mostrar duas ferramentas.", "A primeira", "é simples", "Outra gravação",
        ])
    }

    @Test func aSentenceHasAtMostFourLines() {
        let captions = (0..<6).map { cue("word\($0)", Double($0), Double($0) + 0.9) }
        #expect(CaptionTranslationBuilder.sentences(from: captions).map(\.count) == [4, 2])
    }

    @Test func aTranslatedSentenceIsBrokenIntoLinesOverItsTime() {
        let sentence = [cue("Hoje vou mostrar", 0, 1.5), cue("duas ferramentas.", 1.5, 3)]
        let lines = CaptionTranslationBuilder.lines("Today I will show you two tools that changed how I work every day.", for: sentence)
        #expect(lines.count > 1)
        #expect(lines.allSatisfy { CaptionText.length(CaptionText.words(in: $0.text)) <= CaptionTranslationBuilder.lineLength })
        #expect(lines.first?.start == 0)
        #expect(abs((lines.last?.end ?? 0) - 3) < 0.000_1)
        #expect(lines.allSatisfy { $0.cueIDs == sentence.map(\.id) && $0.sourceText == "Hoje vou mostrar duas ferramentas." })
        // A translation shows whole: no word times.
        #expect(lines.allSatisfy { $0.cue.words.isEmpty })
    }

    @Test func aChangedOriginalMakesItsTranslationOutdated() {
        var captions = [cue("Hello there.", 0, 1)]
        let lines = CaptionTranslationBuilder.lines("Olá.", for: captions)
        let translation = CaptionTranslation(language: .portugueseBrazil, lines: lines)
        #expect(translation.outdatedLines(against: captions).isEmpty)
        captions[0].text = "Hello, everyone."
        #expect(translation.outdatedLines(against: captions).map(\.id) == lines.map(\.id))
        #expect(translation.outdatedLines(against: []).count == 1)
    }

    @Test func translatingAgainKeepsCorrectionsUnlessAsked() {
        let captions = [cue("Hello there.", 0, 1), cue("Bye now.", 1.2, 2)]
        let sentences = CaptionTranslationBuilder.sentences(from: captions)
        var old = sentences.flatMap { CaptionTranslationBuilder.lines("x", for: $0) }
        old[0].text = "Olá, pessoal."
        old[0].isRevised = true
        let new = sentences.flatMap { CaptionTranslationBuilder.lines("novo", for: $0) }
        let translation = CaptionTranslation(language: .portugueseBrazil, lines: old)
        let kept = CaptionTranslationBuilder.merged(new, keeping: translation, captions: captions, replacingRevised: false)
        #expect(kept.map(\.text) == ["Olá, pessoal.", "novo"])
        let replaced = CaptionTranslationBuilder.merged(new, keeping: translation, captions: captions, replacingRevised: true)
        #expect(replaced.map(\.text) == ["novo", "novo"])
    }

    @Test func theDisplayPicksTheLinesThatShow() {
        var edit = TakeEdit(sourceDuration: 10, aspect: .portrait)
        edit.captions = [cue("Hello there.", 1, 2)]
        edit.captionTranslations = [CaptionTranslation(language: .spanish, lines: CaptionTranslationBuilder.lines("Hola.", for: edit.captions))]
        #expect(edit.shownCaptions.main.map(\.text) == ["Hello there."])
        edit.captionDisplay = .translation(.spanish)
        #expect(edit.shownCaptions.main.map(\.text) == ["Hola."])
        #expect(edit.shownCaptions.second.isEmpty)
        edit.captionDisplay = .bilingual(.spanish)
        #expect(edit.shownCaptions.main.map(\.text) == ["Hello there."])
        #expect(edit.shownCaptions.second.map(\.text) == ["Hola."])
        // A display for a translation that's gone shows the original.
        edit.captionDisplay = .translation(.french)
        #expect(edit.shownCaptions.main.map(\.text) == ["Hello there."])
    }
}
