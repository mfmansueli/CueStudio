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
        #expect(prompt.contains("between \(ReadTime.words(for: 60)) and \(ReadTime.words(for: 90)) spoken words"))
        #expect(prompt.contains("must be at least \(ReadTime.words(for: 60)) words"))
        #expect(prompt.contains("several complete sentences"))
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
