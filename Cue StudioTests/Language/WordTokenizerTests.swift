//
//  WordTokenizerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The one tokenizer behind Voice Following, captions and Clean Up.
@Suite("WordTokenizer")
struct WordTokenizerTests {
    // MARK: - Words

    @Test func englishAndPortugueseSplitAsBefore() {
        let words = WordTokenizer.words(in: "Olá, VOCÊ! Don't stop—now. It’s 10x")
        #expect(words.map(\.text) == ["Olá", "VOCÊ", "Dont", "stop", "now", "Its", "10x"])
        #expect(words.map(\.offset) == [0, 5, 11, 17, 22, 27, 32])
    }

    @Test func unspacedTextSplitsIntoDictionaryWordsWithDigitsApart() {
        let words = WordTokenizer.words(in: "水を3杯飲みます", language: .japanese).map(\.text)
        #expect(words.contains("3"))
        #expect(words.count >= 4)
        #expect(words.joined() == "水を3杯飲みます")
    }

    // MARK: - Keys

    @Test func keysFoldCaseAccentsAndWidth() {
        #expect(WordTokenizer.key("VOCÊ") == "voce")
        #expect(WordTokenizer.key("Straße") == "strasse")
        #expect(WordTokenizer.key("３") == "3")
        #expect(WordTokenizer.key("ｶﾀｶﾅ") == "カタカナ")
        #expect(WordTokenizer.key("—") == "")
    }

    /// Recognition writes Arabic without the hamza, vowel marks or stretching a script may have.
    @Test func arabicLetterFormsFoldToOne() {
        #expect(WordTokenizer.key("أشرب") == WordTokenizer.key("اشرب"))
        #expect(WordTokenizer.key("إلى") == WordTokenizer.key("الي"))
        #expect(WordTokenizer.key("مدرسة") == WordTokenizer.key("مدرسه"))
        #expect(WordTokenizer.key("كوبًا") == WordTokenizer.key("كوبا"))
        #expect(WordTokenizer.key("كـتـاب") == WordTokenizer.key("كتاب"))
    }

    /// Hindi: the nukta dot and chandrabindu come and go between a script and a transcription;
    /// vowel signs never do, so they stay.
    @Test func hindiDotsFoldButVowelSignsStay() {
        #expect(WordTokenizer.key("फ़ोन") == WordTokenizer.key("फोन"))
        #expect(WordTokenizer.key("\u{095E}ोन") == WordTokenizer.key("फोन"))
        #expect(WordTokenizer.key("हूँ") == WordTokenizer.key("हूं"))
        #expect(WordTokenizer.key("पानी") != WordTokenizer.key("पन"))
    }

    /// Thai and Devanagari marks are letters of the word, not accents.
    @Test func thaiMarksStay() {
        #expect(WordTokenizer.key("ดื่ม") == "ดื่ม")
        #expect(WordTokenizer.key("น้ำ") != WordTokenizer.key("นา"))
    }

    // MARK: - Numbers

    @Test(arguments: [
        (CueLanguage.english, "3", "three"),
        (.portugueseBrazil, "3", "três"),
        (.spanish, "21", "veintiuno"),
        (.japanese, "3", "三"),
        (.chineseSimplified, "3", "三"),
    ])
    func numbersInDigitsMatchNumbersInWords(language: CueLanguage, digits: String, words: String) {
        let spelled = WordTokenizer.matchingKeys(in: words, language: language)
        #expect(WordTokenizer.matchingKeys(of: digits, language: language) == spelled)
    }

    @Test func numbersStayAsWrittenWithoutALanguageOrWhenLong() {
        #expect(WordTokenizer.matchingKeys(of: "3", language: nil) == ["3"])
        #expect(WordTokenizer.matchingKeys(of: "20260", language: .english) == ["20260"])
        #expect(WordTokenizer.matchingKeys(of: "10x", language: .english) == ["10x"])
        #expect(WordTokenizer.matchingKeys(of: "—", language: .english).isEmpty)
    }

    // MARK: - Display

    @Test func captionWordsKeepTheirPunctuationInEveryScript() {
        #expect(WordTokenizer.displayWords(in: "Okay, real talk.") == ["Okay,", "real", "talk."])
        let japanese = WordTokenizer.displayWords(in: "今日は。まず、水を飲みます。", language: .japanese)
        #expect(japanese.joined() == "今日は。まず、水を飲みます。")
        #expect(japanese.contains { $0.hasSuffix("。") })
        #expect(japanese.count > 3)
    }

    // MARK: - Clean Up

    @Test func spokenFormKeepsAccentsAndShortensHeldSounds() {
        #expect(WordTokenizer.spokenForm("Ummmm,") == "umm")
        #expect(WordTokenizer.spokenForm("É") == "é")
        #expect(WordTokenizer.spokenForm("é") != WordTokenizer.spokenForm("e"))
        #expect(WordTokenizer.spokenForm("Don't!") == "don't")
    }
}
