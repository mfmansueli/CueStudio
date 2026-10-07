//
//  WritingAnalyzerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Each sample voice is analysed and Cue has to find what that person is like (and say nothing it can't see).
@Suite("Import my writing · what Cue finds")
struct WritingAnalyzerTests {
    private func pieces(_ texts: [String]) -> [WritingPiece] {
        texts.map { WritingPiece(text: $0, source: "Pasted") }
    }

    @Test func anEnergeticCoachSoundsShortLivelyAndPlain() throws {
        let analysis = WritingAnalyzer.analyze(pieces(WritingSamples.maya))
        #expect(analysis.language == "en")
        #expect(analysis.sentences == .short)
        #expect(analysis.energy == .high)
        #expect(analysis.words == .plain)
        #expect(analysis.speaksAs == .i)
        #expect(analysis.length == .under30)
        #expect(analysis.phrases.contains("Okay, real talk"))
        #expect(Set(analysis.openings) == ["Question", "Start with a number"])
        #expect(Set(analysis.endings) == ["Save this", "Try it and tell me"])
        let fingerprint = try #require(analysis.fingerprint)
        #expect(fingerprint.isReliable)
        #expect(fingerprint.exclamationShare > 0.25)
    }

    @Test func aCalmExplainerWritesLongerSentencesAndNoExclamations() throws {
        let analysis = WritingAnalyzer.analyze(pieces(WritingSamples.daniel))
        #expect(analysis.sentences != .short)
        #expect(analysis.energy == .calm)
        #expect(analysis.phrases.contains("Here's the thing"))
        #expect(analysis.phrases.contains("Follow for part two"))
        #expect(analysis.endings == ["Follow for more"])
        #expect(analysis.speaksAs == .i)
        let maya = try #require(WritingAnalyzer.analyze(pieces(WritingSamples.maya)).fingerprint)
        let daniel = try #require(analysis.fingerprint)
        #expect(daniel.wordsPerSentence > maya.wordsPerSentence + 4)
        #expect(daniel.exclamationShare == 0)
    }

    @Test func aPortugueseCreatorGetsHerGreetingAndHerSlang() {
        let analysis = WritingAnalyzer.analyze(pieces(WritingSamples.rafa))
        #expect(analysis.language == "pt")
        #expect(analysis.phrases.first == "Fala, galera")
        #expect(analysis.words == .someSlang)
        #expect(Set(analysis.endings) == ["Comment your answer", "Save this"])
    }

    @Test func aShopThatSaysWeIsFoundToSpeakAsATeam() {
        let analysis = WritingAnalyzer.analyze(pieces(WritingSamples.lucia))
        #expect(analysis.language == "es")
        #expect(analysis.speaksAs == .we)
    }

    @Test func twoTextsGiveMeasuresButNoHabits() {
        let analysis = WritingAnalyzer.analyze(pieces(Array(WritingSamples.maya.prefix(2))))
        #expect(analysis.fingerprint != nil)
        #expect(analysis.phrases.isEmpty && analysis.openings.isEmpty && analysis.endings.isEmpty && analysis.length == nil)
    }

    @Test func aTextInAnotherLanguageIsLeftOutOfTheMeasures() {
        let mixed = pieces(WritingSamples.maya + Array(WritingSamples.rafa.prefix(2)))
        let analysis = WritingAnalyzer.analyze(mixed)
        #expect(analysis.language == "en")
        #expect(analysis.languageShares["pt"] ?? 0 > 0.05)
        #expect(analysis.fingerprint?.pieces == WritingSamples.maya.count)
        #expect(analysis.excerpts.allSatisfy { $0.language == "en" })
    }

    @Test func aCreatorWhoSwearsIsNotAskedToStopAndTheirWordsAreNotKept() {
        var texts = WritingSamples.maya
        texts[0] = "This is the fucking best workout I have ever done and honestly you should do it too before the week is over."
        let analysis = WritingAnalyzer.analyze(pieces(texts))
        #expect(analysis.blockedPieces == 1)
        #expect(analysis.swearing == .mild)
        #expect(!analysis.excerpts.contains { VoiceTextValidator.isBlocked($0.text) })
    }

    @Test func aLongCleanTextSaysTheCreatorNeverSwears() {
        let analysis = WritingAnalyzer.analyze(pieces(WritingSamples.daniel + WritingSamples.daniel.map { $0 + " Thanks for watching." }))
        #expect(analysis.swearing == .never)
    }

    @Test func nothingIsSaidOfWhatAFewWordsCannotShow() {
        let analysis = WritingAnalyzer.analyze(pieces(["Okay, real talk. Do you really need a gym membership to get stronger this year?"]))
        #expect(analysis.sentences == nil && analysis.energy == nil && analysis.words == nil && analysis.swearing == nil)
    }

    @Test func nothingToReadGivesAnEmptyAnalysis() {
        #expect(WritingAnalyzer.analyze([]).isEmpty)
    }

    @Test func languagesWrittenWithoutSpacesGetNoSentenceLength() {
        let japanese = (1...4).map { _ in "今日は朝の習慣についてお話しします。まず水を飲みます。次に五分だけストレッチをします。最後に今日の一番大事なことを書きます。" }
        let analysis = WritingAnalyzer.analyze(pieces(japanese.enumerated().map { $0.element + String(repeating: "。", count: 0) + "\($0.offset)" }))
        #expect(analysis.sentences == nil)
    }
}
