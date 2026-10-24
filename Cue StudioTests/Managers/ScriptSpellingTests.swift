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
        let heardWords: [String] = "so today I want to talk about something else entirely".split(separator: " ").map(String.init)
        #expect(!result.followsScript)
        #expect(result.words.map(\.text) == heardWords)
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

    @Test func aNumberTakesTheScriptsWritingOnlyWhenItIsTheSameNumber() {
        let script = "We need 5 apples for the pie today."
        #expect(text(ScriptSpelling.apply(to: heard("we need five apples for the pie today"), script: script, language: .english)) == script)
        // Another number stays as said, in digits or in words.
        #expect(text(ScriptSpelling.apply(to: heard("we need six apples for the pie today"), script: script, language: .english)).contains("six"))
        let teens = ScriptSpelling.apply(
            to: heard("she turned seventy years old this week"), script: "She turned seventeen years old this week.", language: .english
        )
        #expect(text(teens).contains("seventy"))
    }

    /// The system voice on an iPhone: Vietnamese written in digits where the script spells the numbers out.
    @Test func aNumberInDigitsTakesTheScriptsWords() {
        let result = ScriptSpelling.apply(
            to: heard("đây là 3 thói quen đã thay đổi buổi sáng của tôi"), script: "Đây là ba thói quen đã thay đổi buổi sáng của tôi.",
            language: .vietnamese
        )
        #expect(text(result) == "Đây là ba thói quen đã thay đổi buổi sáng của tôi.")
    }

    /// A Dutch reading on an iPhone: the recognizer wrote "2006" as three numbers.
    @Test func digitsTheRecognizerCutUpAreTheScriptsNumber() {
        let words = heard("volgens angel 2 00 6 kunnen organisaties beter presteren")
        let result = ScriptSpelling.apply(to: words, script: "Volgens Angel (2006) kunnen organisaties beter presteren.", language: .dutch)
        #expect(text(result) == "Volgens Angel (2006) kunnen organisaties beter presteren.")
        let year = result.words[2]
        #expect(year.start == words[2].start && year.end == words[4].end && year.isEstimated)
        // Other digits stay as heard: one is missing from these.
        let missing = ScriptSpelling.apply(to: heard("volgens angel 2 0 6 kunnen organisaties beter presteren"),
                                           script: "Volgens Angel (2006) kunnen organisaties beter presteren.", language: .dutch)
        #expect(!text(missing).contains("2006"))
    }

    /// Articles that also count one aren't numbers to swap: "einen" was said, the script has "ein".
    @Test func anArticleThatAlsoCountsOneIsLeftAsSaid() {
        let result = ScriptSpelling.apply(
            to: heard("ich sehe einen hund im park heute morgen"), script: "Ich sehe ein Hund im Park heute Morgen.", language: .german
        )
        #expect(text(result).contains("einen"))
    }

    /// A Portuguese reading on an iPhone: a racing driver's name heard as five other words.
    @Test func aNameHeardAsOtherWordsIsWrittenAsTheScriptHasIt() {
        let script = "Giancarlo Fisichella perdeu o controle do carro e acabou a corrida logo após a largada."
        let words = heard("jean carlos disse que ela perdeu o controle do carro e acabou a corrida logo após a largada")
        let result = ScriptSpelling.apply(to: words, script: script, language: .portugueseBrazil)
        #expect(text(result) == script)
        // The name takes the time the voice took for it, shared as an estimate.
        #expect(result.words[0].start == words[0].start && abs(result.words[1].end - words[4].end) < 0.0001)
        #expect(result.words[0].isEstimated && result.words[1].isEstimated)
        // Improvised, nothing is taken for a name.
        let improvised = ScriptSpelling.apply(
            to: heard("jean carlos disse que ela gosta muito de cozinhar aos domingos com a família"), script: script,
            language: .portugueseBrazil
        )
        #expect(text(improvised).hasPrefix("jean carlos"))
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

    /// The creator greeted in Portuguese where the script has an English greeting: what was said stays.
    @Test func aPhraseInAnotherLanguageIsWrittenOnlyWhenItSoundsLikeWhatWasHeard() {
        let script = "Hey guys welcome back. Hoje vou mostrar três hábitos que mudaram minhas manhãs."
        let result = ScriptSpelling.apply(
            to: heard("oi gente tudo bem hoje vou mostrar três hábitos que mudaram minhas manhãs"), script: script, language: .portugueseBrazil
        )
        #expect(result.followsScript)
        #expect(text(result).hasPrefix("oi gente tudo bem Hoje"))
    }

    @Test func aMarkTheRecognizerWroteOnItsOwnIsntRepeated() {
        let result = ScriptSpelling.apply(to: heard("first point here ."), script: "First point here.")
        #expect(text(result) == "First point here.")
    }

    @Test func anEnglishPhraseIsLeftAsHeardWhenTheTakeDidntFollowTheScriptOrTheLengthsDiffer() {
        let script = "Hey guys welcome back. Hoje vou mostrar três hábitos que mudaram minhas manhãs."
        let different = ScriptSpelling.apply(
            to: heard("rei hoje vou mostrar três hábitos que mudaram minhas manhãs"), script: script, language: .portugueseBrazil
        )
        // "rei" stays as heard; the words that line up still take the script's spelling ("Hoje").
        #expect(text(different).hasPrefix("rei Hoje vou mostrar"))
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

    /// A 20-minute take read from its script, a name and a few words misheard in every sentence: spelled in a second or so (off
    /// the main thread, once, after a transcription that takes minutes); the bound catches a rule gone slow, not a busy Mac.
    @Test func aLongTakeIsSpelledQuickly() {
        let sentence = "Today Giancarlo Fisichella shows how the new camera from Sony handles light in the evening"
        let misheard = "today jean carlos disse que ela shows how the new kamera from sunny handles light in the evening"
        let script = Array(repeating: sentence + ".", count: 120).joined(separator: " ")
        let words = heard(Array(repeating: misheard, count: 120).joined(separator: " "))
        let started = ProcessInfo.processInfo.systemUptime
        let result = ScriptSpelling.apply(to: words, script: script, language: .english)
        let seconds = ProcessInfo.processInfo.systemUptime - started
        #expect(result.followsScript)
        #expect(text(result).hasPrefix("Today Giancarlo Fisichella shows how the new camera from Sony handles"))
        #expect(seconds < 3, "\(seconds) s for \(words.count) words")
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
        // 300 distinct words of letters only: words with digits are never handed over.
        let letters = Array("abcdefghijklmnopqrstuvwxyz")
        let words: [String] = (0..<300).map { (index: Int) -> String in "word\(letters[index / 26])\(letters[index % 26])" }
        let script = words.joined(separator: " ")
        #expect(ScriptVocabulary.terms(in: script).count == ScriptVocabulary.limit)
        #expect(ScriptVocabulary.terms(in: "word1 word2 word3").isEmpty)
    }

    @Test func aScriptWithNoWordsHasNoTerms() {
        #expect(ScriptVocabulary.terms(in: "").isEmpty)
    }
}
