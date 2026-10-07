//
//  VoiceFingerprintRulesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What was measured of the creator's writing, told to the model and checked on its script.
@Suite("Import my writing · measured habits")
struct VoiceFingerprintRulesTests {
    private func voice(from texts: [String], answeringSentences: SentenceLength? = nil) -> CreatorVoice {
        var voice = CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [], niches: [], role: nil)
        voice.fingerprint = WritingAnalyzer.analyze(texts.map { WritingPiece(text: $0) }).fingerprint
        voice.style.sentences = answeringSentences
        return voice
    }

    private let english = CueLanguage.english

    @Test func theBriefSaysHowLongTheirSentencesRunAndWhatTheyAlmostNeverDo() {
        let lines = VoiceFingerprintRules.lines(for: voice(from: WritingSamples.daniel))
        #expect(lines.contains { $0.hasPrefix("Their sentences average about ") && $0.hasSuffix(" words.") })
        #expect(lines.contains("They almost never use exclamation marks."))
    }

    @Test func whatTheCreatorAnsweredThemselfIsNotSaidAgain() {
        let lines = VoiceFingerprintRules.lines(for: voice(from: WritingSamples.daniel, answeringSentences: .long))
        #expect(!lines.contains { $0.hasPrefix("Their sentences") })
    }

    @Test func tooLittleWritingSaysNothing() {
        #expect(VoiceFingerprintRules.lines(for: voice(from: Array(WritingSamples.daniel.prefix(1)))).isEmpty)
        #expect(VoiceFingerprintRules.lines(for: CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [], niches: [], role: nil)).isEmpty)
    }

    @Test func aScriptThatShoutsInChoppySentencesDriftsFromACalmCreator() {
        let calm = voice(from: WritingSamples.daniel)
        let script = "Save money! Do it now! Skip coffee! Invest early! Never stop! Win big!"
        let kinds = VoiceFingerprintRules.drift(in: script, voice: calm, language: english).map(\.kind)
        #expect(Set(kinds) == [.sentenceLength, .exclamation])
        #expect(VoiceFingerprintRules.drift(in: script, voice: calm, language: english).allSatisfy { $0.isSoft })
    }

    @Test func aScriptInTheirOwnStyleDoesNotDrift() {
        let calm = voice(from: WritingSamples.daniel)
        let script = WritingSamples.daniel[2] + " " + WritingSamples.daniel[4]
        #expect(VoiceFingerprintRules.drift(in: script, voice: calm, language: english).isEmpty)
    }

    @Test func aScriptInAnotherLanguageIsNotMeasuredAgainstThem() {
        let calm = voice(from: WritingSamples.daniel)
        let script = "Fale agora! Compre já! Pare tudo! Corra! Siga em frente! Vença hoje!"
        #expect(VoiceFingerprintRules.drift(in: script, voice: calm, language: CueLanguage.portugueseBrazil).isEmpty)
    }

    @Test func aMeasureOnlyCountsAndNeverMakesAScriptBeWrittenAgain() {
        let violations = [VoiceViolation(kind: .sentenceLength, detail: "x"), VoiceViolation(kind: .exclamation, detail: "y")]
        #expect(violations.allSatisfy { $0.isSoft })
        #expect(!VoiceViolation(kind: .avoided, detail: "z").isSoft)
    }

    @Test func theBriefHoldsTheImportedExcerptsBeforeTheCreatorsOwnExamples() {
        var creator = voice(from: WritingSamples.maya)
        creator.role = .expert
        creator.examples = [VoiceExample(text: "A pasted example that is long enough to be sent to the model as it is.")]
        creator.excerpts = WritingAnalyzer.analyze(WritingSamples.maya.map { WritingPiece(text: $0) }).excerpts.prefix(2).map { $0 }
        let brief = VoiceBriefBuilder.brief(for: creator)
        let lines = brief.lines
        let header = lines.firstIndex { $0.hasPrefix("Here is how they write") }
        #expect(header != nil)
        let first = lines.first { $0.hasPrefix("- “") }
        #expect(first?.contains("A pasted example") == false)
        #expect(brief.length <= VoiceBrief.budget)
    }
}
