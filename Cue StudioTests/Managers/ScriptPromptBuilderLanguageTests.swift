//
//  ScriptPromptBuilderLanguageTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The language and length rules in what the model is told. Both were found on an iPhone: a Japanese idea with an
/// English catchphrase came back in English, and a request for 150 to 225 words came back with about a third of that.
@Suite("ScriptPromptBuilder language and length")
struct ScriptPromptBuilderLanguageTests {
    private func request(_ language: CueLanguage?, variant: Locale? = nil) -> ScriptRequest {
        ScriptRequest(
            source: .prompt("Why I quit coffee"), platform: .tiktok, tone: nil, voice: nil, targetRange: 60...90,
            language: language, languageVariant: variant
        )
    }

    @Test func aLanguageOtherThanEnglishIsNamedFirmly() {
        let instructions = ScriptPromptBuilder.instructions(for: request(.japanese))
        #expect(instructions.contains("Write the title and every block in Japanese."))
        #expect(instructions.contains("not in English"))
        #expect(instructions.contains("catchphrases stay as they are"))
    }

    @Test func englishNeedsNoInsistenceUnlessAskedFor() {
        let plain = ScriptPromptBuilder.instructions(for: request(.english))
        #expect(!plain.contains("not in English"))
        #expect(ScriptPromptBuilder.instructions(for: request(.english), insistsOnLanguage: true).contains("not in English"))
    }

    @Test func theCreatorsVariantIsNamedWhereThereIsOne() {
        let instructions = ScriptPromptBuilder.instructions(for: request(.portugueseBrazil, variant: Locale(identifier: "pt-PT")))
        #expect(instructions.contains("Portuguese (Portugal)"))
    }

    @Test func theLengthIsAMinimumAndNotJustARange() {
        let prompt = ScriptPromptBuilder.prompt(for: request(.english))
        let asked = ScriptPromptBuilder.askedRange(for: 60...90)
        #expect(prompt.contains("between \(asked.low) and \(asked.high) spoken words"))
        #expect(prompt.contains("must be at least \(asked.low) words"))
        #expect(asked.low >= ReadTime.words(for: 60) && asked.high >= ReadTime.words(for: 90), "the model is asked for at least what the platform needs")
        // A video of a minute or so is asked as it is, with no count of sentences (`shortFormWords`): that is what made one idea take minutes.
        #expect(asked.low == ReadTime.words(for: 60))
        #expect(!prompt.contains("sentences in every block"))
    }

    @Test func aScriptOfAFewMinutesIsAskedInSentencesForEveryBlock() {
        let asked = ScriptPromptBuilder.askedRange(for: 90...150)
        let rule = ScriptPromptBuilder.lengthRule(minimumWords: asked.low, blocks: 3)
        #expect(rule.contains("sentences in every block"), "a count of sentences, which the model can follow")
    }

    @Test func aLongScriptIsAskedAsItIsAndNotInSentencesForEveryBlock() {
        let asked = ScriptPromptBuilder.askedRange(for: 480...900)
        #expect(asked.low == ReadTime.words(for: 480), "the model already writes the length of a YouTube video")
        #expect(ScriptPromptBuilder.lengthRule(minimumWords: asked.low, blocks: 6).contains("many complete sentences"))
        #expect(!ScriptPromptBuilder.lengthRule(minimumWords: asked.low, blocks: 6).contains("in every block"))
    }

    @Test func aScriptOfAFewMinutesIsAskedForMoreWordsThanItNeedsAndTheCeilingStaysPut() {
        let asked = ScriptPromptBuilder.askedRange(for: 90...120)
        #expect(asked.low == Int((Double(ReadTime.words(for: 90)) * ScriptPromptBuilder.lengthAskFactor).rounded()))
        #expect(asked.high == max(ReadTime.words(for: 120), Int((Double(asked.low) * 1.25).rounded())))
    }

    @Test func theSentencesAskedForFollowHowLongTheCreatorsSentencesRun() {
        #expect(ScriptPromptBuilder.sentenceWords(for: nil) == 12)
        var voice = CreatorVoice(sounds: [], phrases: [], vocabulary: nil, styles: [], niches: [], role: nil)
        voice.style.sentences = .short
        #expect(ScriptPromptBuilder.sentenceWords(for: voice) == 9)
        voice.style.sentences = .long
        #expect(ScriptPromptBuilder.sentenceWords(for: voice) == 18)
        #expect(ScriptPromptBuilder.lengthRule(minimumWords: 240, blocks: 4, sentenceWords: 9).contains("at least 7 sentences in every block"))
    }

    @Test func aRewriteNamesTheLanguageItMustStayIn() {
        let japanese = ScriptPromptBuilder.rewriteInstructions(voice: nil, language: Locale.Language(identifier: "ja"))
        #expect(japanese.contains("The result is in Japanese, not in English"))
        let english = ScriptPromptBuilder.rewriteInstructions(voice: nil, language: Locale.Language(identifier: "en"))
        #expect(!english.contains("not in English"))
        #expect(!ScriptPromptBuilder.rewriteInstructions().contains("not in English"))
    }

    @Test func aTranslationsTargetIsNamed() {
        let instructions = ScriptPromptBuilder.rewriteInstructions(voice: nil, language: CueLanguage.chineseTraditional.locale.language)
        #expect(instructions.contains("Chinese"))
    }
}
