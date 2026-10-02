//
//  ScriptSpellingTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the script lends to the heard words: spelling and punctuation, more when the take was read
/// from it, never what was said.
@Suite("Script spelling")
struct ScriptSpellingTests {
    /// Heard words, 0.4 s apart.
    private func heard(_ line: String) -> [CaptionWord] {
        line.split(separator: " ").enumerated().map { index, word in
            CaptionWord(text: String(word), start: Double(index) * 0.4, end: Double(index) * 0.4 + 0.3)
        }
    }

    private func text(_ result: ScriptSpelling.Result) -> String {
        CaptionText.joined(result.words.map(\.text))
    }

    @Test func aTakeReadFromTheScriptIsRecognizedAsSuch() {
        let result = ScriptSpelling.apply(to: heard("hoje vou mostrar duas ferramentas simples"), script: "Hoje vou mostrar duas ferramentas simples.")
        #expect(result.followsScript)
        #expect(result.coverage == 1)
        #expect(text(result) == "Hoje vou mostrar duas ferramentas simples.")
    }

    @Test func anImprovisedTakeIsNot() {
        let result = ScriptSpelling.apply(
            to: heard("so today I want to talk about something else entirely"), script: "Hoje vou mostrar duas ferramentas simples."
        )
        #expect(!result.followsScript)
        #expect(result.words.map(\.text) == "so today I want to talk about something else entirely".split(separator: " ").map(String.init))
    }

    @Test func aMishearingBetweenWordsThatLineUpTakesTheScriptsWord() {
        let result = ScriptSpelling.apply(
            to: heard("hoje vou mostra duas ferramentas simples agora"), script: "Hoje vou mostrar duas ferramentas simples agora."
        )
        #expect(result.followsScript)
        #expect(text(result) == "Hoje vou mostrar duas ferramentas simples agora.")
        // The voice's times stay on the corrected word.
        #expect(result.words[2].start == 0.8 && !result.words[2].isEstimated)
    }

    @Test func aWordThatIsReallyDifferentStaysAsSaid() {
        let result = ScriptSpelling.apply(
            to: heard("hoje vou mostrar tres ferramentas simples agora"), script: "Hoje vou mostrar duas ferramentas simples agora."
        )
        #expect(text(result).contains("tres"))
        #expect(!text(result).contains("duas"))
    }

    @Test func aNumberIsNeverRewrittenEvenWhenTheTakeFollowsTheScript() {
        let result = ScriptSpelling.apply(to: heard("we need five apples for the pie today"), script: "We need 5 apples for the pie today.")
        #expect(text(result).contains("five"))
    }

    @Test func aShortWordBetweenWordsThatLineUpTakesTheScriptsSpellingOnlyWhenTheTakeFollowsIt() {
        let followed = ScriptSpelling.apply(to: heard("a big dog ran fast"), script: "A huge dog ran fast.")
        #expect(followed.followsScript)
        #expect(text(followed) == "A big dog ran fast.")
        // Improvised: the same lone "a" is left as heard.
        let improvised = ScriptSpelling.apply(to: heard("a story about my cat sleeping all day"), script: "A huge dog ran fast.")
        #expect(!improvised.followsScript)
        #expect(improvised.words.first?.text == "a")
    }

    @Test func aNegationTheScriptDoesntHaveIsKept() {
        let result = ScriptSpelling.apply(to: heard("i will not go"), script: "I will go.")
        #expect(text(result) == "I will not go")
    }

    @Test func wordsSplitDifferentlyTakeTheScriptsAndShareTheTimeAsAnEstimate() {
        let words = heard("read the news paper today")
        let result = ScriptSpelling.apply(to: words, script: "Read the newspaper today.")
        #expect(text(result) == "Read the newspaper today.")
        let merged = result.words[2]
        #expect(merged.start == words[2].start && merged.end == words[3].end)
        #expect(merged.isEstimated)
    }

    @Test func anEnglishPhraseTheRecognizerHeardAsPortugueseGibberishIsWrittenAsTheScriptHasIt() {
        let script = "Hey guys welcome back. Hoje vou mostrar três hábitos que mudaram minhas manhãs."
        let words = heard("rei gais uélcam béqui hoje vou mostrar três hábitos que mudaram minhas manhãs")
        let result = ScriptSpelling.apply(to: words, script: script, language: .portugueseBrazil)
        #expect(result.followsScript)
        #expect(text(result).hasPrefix("Hey guys welcome back. Hoje vou mostrar"))
        // The voice's times stay on the words.
        #expect(result.words.prefix(4).map(\.start) == words.prefix(4).map(\.start))
    }

    @Test func anEnglishPhraseIsLeftAsHeardWhenTheTakeDidntFollowTheScriptOrTheLengthsDiffer() {
        let script = "Hey guys welcome back. Hoje vou mostrar três hábitos que mudaram minhas manhãs."
        let different = ScriptSpelling.apply(
            to: heard("rei hoje vou mostrar três hábitos que mudaram minhas manhãs"), script: script, language: .portugueseBrazil
        )
        #expect(text(different).hasPrefix("rei hoje vou mostrar"))
        let improvised = ScriptSpelling.apply(
            to: heard("rei gais uélcam béqui e agora uma história totalmente diferente sobre outra coisa"), script: script, language: .portugueseBrazil
        )
        #expect(!improvised.followsScript)
        #expect(text(improvised).hasPrefix("rei gais"))
    }

    @Test func skippedLinesNeverAppear() {
        let script = "First point here. Second point is long and careful. Third point here."
        let result = ScriptSpelling.apply(to: heard("first point here third point here"), script: script)
        #expect(!text(result).contains("Second"))
        #expect(text(result) == "First point here. Third point here.")
    }

    @Test func accentsAndCasesFoldWhenComparing() {
        let result = ScriptSpelling.apply(to: heard("voce ja sabe tudo isso"), script: "Você já sabe tudo isso.")
        #expect(text(result) == "Você já sabe tudo isso.")
    }

    @Test func similarityIsTheShareOfLettersKept() {
        #expect(ScriptSpelling.ratio("mostra", "mostrar") > 0.8)
        #expect(ScriptSpelling.ratio("duas", "tres") < 0.5)
        #expect(ScriptSpelling.ratio("same", "same") == 1)
        #expect(ScriptSpelling.ratio("", "x") == 0)
    }

    @Test func noScriptOrNoWordsChangesNothing() {
        let words = heard("just talking here")
        #expect(ScriptSpelling.apply(to: words, script: "").words == words)
        #expect(ScriptSpelling.apply(to: [], script: "Anything").words.isEmpty)
    }
}

@Suite("Script vocabulary")
struct ScriptVocabularyTests {
    @Test func namesAndLongWordsComeFirstAndEachWordOnce() {
        let terms = ScriptVocabulary.terms(in: "Today I met Marcela and we talked about photosynthesis. Marcela knows plants well.")
        #expect(terms.first == "Marcela")
        #expect(terms.contains("photosynthesis"))
        #expect(terms.filter { $0.lowercased() == "marcela" }.count == 1)
        #expect(!terms.contains("and"))
    }

    @Test func cuesAndNumbersAreLeftOut() {
        let terms = ScriptVocabulary.terms(in: "[pause] Chapter 2020 starts with orchestras.")
        #expect(!terms.contains("pause"))
        #expect(!terms.contains("2020"))
        #expect(terms.contains("orchestras"))
    }

    @Test func theListIsCapped() {
        let script = (0..<300).map { "word\($0)long" }.joined(separator: " ")
        #expect(ScriptVocabulary.terms(in: script).count == ScriptVocabulary.limit)
    }

    @Test func aScriptWithNoWordsHasNoTerms() {
        #expect(ScriptVocabulary.terms(in: "").isEmpty)
    }
}
