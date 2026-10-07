//
//  ExcerptSelectionTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The excerpts kept from what the creator imported, and the ones each request is sent.
@Suite("Import my writing · excerpts")
struct ExcerptSelectionTests {
    private func library(_ texts: [String]) -> [VoiceExcerpt] {
        WritingAnalyzer.analyze(texts.map { WritingPiece(text: $0, source: "Pasted") }).excerpts
    }

    @Test func theExcerptsAreWholeSentencesThatFitAndCoverOpeningBodyAndClosing() {
        let excerpts = library(WritingSamples.maya + WritingSamples.daniel.prefix(0))
        #expect(!excerpts.isEmpty && excerpts.count <= VoiceExcerpt.limit)
        #expect(excerpts.allSatisfy { $0.text.count <= VoiceExcerpt.maximumCharacters && $0.wordCount >= VoiceExcerpt.minimumWords })
        #expect(Set(excerpts.map(\.role)) == Set(VoiceExcerpt.Role.allCases))
        #expect(excerpts.allSatisfy { ".!?".contains($0.text.last ?? " ") })
    }

    @Test func noExcerptComesTwiceOrFromOneTextMoreThanTwice() {
        let excerpts = library(WritingSamples.maya)
        #expect(Set(excerpts.map(\.text)).count == excerpts.count)
        #expect(excerpts.count <= WritingSamples.maya.count * ExcerptSelector.perPiece)
    }

    @Test func nothingThatCouldIdentifyAnyoneIsKept() {
        let excerpts = library(WritingSamples.maya + [WritingSamples.messyPaste])
        #expect(excerpts.allSatisfy { !$0.text.contains("@") && !$0.text.lowercased().contains("http") })
        #expect(excerpts.allSatisfy { $0.text.range(of: #"\d{5,}"#, options: .regularExpression) == nil })
    }

    @Test func aRequestGetsAnOpeningAndABodyInItsOwnLanguageOnly() {
        let mixed = library(WritingSamples.maya) + library(WritingSamples.rafa)
        let english = ExcerptRetriever.pick(from: mixed, context: .init(language: "en", idea: "my morning routine"), limit: 2)
        #expect(english.count == 2)
        #expect(english.map(\.role) == [.opening, .body])
        #expect(english.allSatisfy { $0.language == "en" })
        let portuguese = ExcerptRetriever.pick(from: mixed, context: .init(language: "pt-BR"), limit: 3)
        #expect(portuguese.count == 3 && portuguese.allSatisfy { $0.language == "pt" })
        #expect(ExcerptRetriever.pick(from: mixed, context: .init(language: "ja")).isEmpty)
    }

    @Test func aThirdExcerptShowsHowTheyClose() {
        let picked = ExcerptRetriever.pick(from: library(WritingSamples.maya), context: .init(language: "en"), limit: 3)
        #expect(picked.map(\.role) == [.opening, .body, .closing])
    }

    @Test func theSameIdeaAlwaysGetsTheSameExcerpts() {
        let kept = library(WritingSamples.maya)
        let context = ExcerptRetriever.Context(language: "en", idea: "five minute stretching")
        #expect(ExcerptRetriever.pick(from: kept, context: context) == ExcerptRetriever.pick(from: kept.shuffled(), context: context))
    }

    @Test func theTwoExcerptsAreNotTheSameSentences() {
        let picked = ExcerptRetriever.pick(from: library(WritingSamples.maya), context: .init(language: "en"), limit: 2)
        #expect(picked.count == 2 && picked[0].text != picked[1].text)
    }

    @Test func aProfessionalPlatformGetsNoExcerptWithEmoji() {
        let plain = VoiceExcerpt(text: "Here is how I plan the week, step by step, so that nothing important is left to the last minute.", language: "en", role: .opening)
        let playful = VoiceExcerpt(text: "Okay real talk 🔥 I plan my week like this and it changed everything for me this year 💪", language: "en", role: .body)
        let picked = ExcerptRetriever.pick(from: [plain, playful], context: .init(language: "en", professional: true), limit: 2)
        #expect(picked == [plain])
        #expect(ExcerptRetriever.pick(from: [plain, playful], context: .init(language: "en"), limit: 2).count == 2)
    }

    @Test func anEmptyLibraryGivesNothing() {
        #expect(ExcerptRetriever.pick(from: [], context: .init(language: "en")).isEmpty)
    }

    @Test func anExcerptWithNoKnownLanguageCanStillBeUsed() {
        let unknown = VoiceExcerpt(text: "Okay, real talk. This is how I explain it to my friends when they ask me about it.", language: nil)
        #expect(ExcerptRetriever.pick(from: [unknown], context: .init(language: "en")) == [unknown])
    }
}
