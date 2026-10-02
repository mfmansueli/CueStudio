//
//  ScriptLanguageRunsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A script is read by the language each sentence is written in.
@Suite("Script language runs")
struct ScriptLanguageRunsTests {
    private let mixed = """
    Hey everyone, welcome back to my channel and thanks for watching this video today. \
    Hoje eu vou mostrar três hábitos simples que mudaram a minha rotina de trabalho. \
    Eles não custam nada e qualquer pessoa consegue começar ainda hoje, sem precisar de equipamento.
    """

    @Test func anEnglishOpeningAndAPortugueseRestAreTwoStretches() {
        let reading = ScriptLanguageRuns.reading(of: mixed)
        #expect(reading.runs.map(\.code) == ["en", "pt"])
        #expect(reading.runs.first?.words.lowerBound == 0)
        #expect(reading.runs.last?.words.upperBound == reading.words.count)
        #expect(reading.runs[0].words.upperBound == reading.runs[1].words.lowerBound)
    }

    @Test func theOtherLanguagesToListenForExcludeTheMainOne() {
        let reading = ScriptLanguageRuns.reading(of: mixed)
        #expect(ScriptLanguageRuns.foreignCodes(in: reading, besides: "pt") == ["en"])
        #expect(ScriptLanguageRuns.foreignCodes(in: reading, besides: "en") == ["pt"])
    }

    @Test func aScriptInOneLanguageIsOneStretch() {
        let reading = ScriptLanguageRuns.reading(of: "Hoje eu vou mostrar três hábitos simples que mudaram a minha rotina. Eles não custam nada.")
        #expect(reading.runs.count == 1)
        #expect(ScriptLanguageRuns.foreignCodes(in: reading, besides: "pt").isEmpty)
    }

    @Test func aShortSentenceBelongsToTheOneAroundIt() {
        let text = "Hoje eu vou mostrar três hábitos simples que mudaram a minha rotina. Okay! Eles não custam nada e qualquer pessoa consegue começar."
        let reading = ScriptLanguageRuns.reading(of: text)
        #expect(reading.runs.map(\.code) == ["pt"])
    }

    @Test func cuesAreNotSpoken() {
        let reading = ScriptLanguageRuns.reading(of: "Hoje eu vou mostrar três hábitos simples. [pause] Eles não custam nada.")
        #expect(!reading.words.contains { $0.contains("pause") })
    }

    @Test func nothingWrittenIsNothingToListenFor() {
        #expect(ScriptLanguageRuns.reading(of: "").runs.isEmpty)
        #expect(ScriptLanguageRuns.reading(of: "").words.isEmpty)
    }
}
