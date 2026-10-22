//
//  DashPunctuationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The marks each language writes where the model put a dash.
@Suite("DashPunctuation")
struct DashPunctuationTests {
    private func marks(_ code: String?) -> DashPunctuation {
        DashPunctuation.forLanguage(code.map(Locale.Language.init(identifier:)))
    }

    @Test func englishIsTheDefault() {
        #expect(marks(nil) == marks("en"))
        #expect(marks("xx").comma == ", " && marks("xx").colon == ": " && marks("xx").fullStop == ". ")
        #expect(marks("en").hasCase && !marks("en").isUnspaced && marks("en").splitsSentences)
    }

    @Test func chineseAndJapaneseWriteFullwidthMarksWithoutSpaces() {
        for code in ["zh-Hans", "zh-Hant"] {
            #expect(marks(code).comma == "，" && marks(code).colon == "：" && marks(code).fullStop == "。")
            #expect(marks(code).isUnspaced && !marks(code).hasCase)
        }
        #expect(marks("ja").comma == "、" && marks("ja").fullStop == "。" && !marks("ja").colonInProse)
    }

    @Test func frenchPutsANarrowNoBreakSpaceBeforeTheColon() {
        #expect(marks("fr").colon == "\u{202F}: ")
    }

    @Test func arabicUsesItsCommaAndNeverSplitsTheSentence() {
        #expect(marks("ar").comma == "، " && !marks("ar").splitsSentences && !marks("ar").hasCase)
        #expect(marks("ar").connectors.isEmpty, "Arabic attaches its connectors to the next word")
    }

    @Test func thaiSeparatesClausesWithASpace() {
        #expect(marks("th").comma == " " && marks("th").colon == " " && marks("th").fullStop == " ")
    }

    @Test func hindiKeepsTheFullStopItsTextUses() {
        #expect(marks("hi").fullStop(inSentenceEndingWith: "।") == "। ")
        #expect(marks("hi").fullStop(inSentenceEndingWith: ".") == ". ")
        #expect(marks("en").fullStop(inSentenceEndingWith: "।") == ". ")
    }

    @Test func connectorsOfOneOrTwoWordsAreKnown() {
        #expect(marks("en").isConnector(firstWords: ["until", "i"]))
        #expect(marks("es").isConnector(firstWords: ["así", "que"]))
        #expect(marks("tr").isConnector(firstWords: ["ta", "ki"]))
        #expect(!marks("en").isConnector(firstWords: ["these", "are"]))
        #expect(!marks("en").isConnector(firstWords: []))
        #expect(marks("zh-Hans").isConnector(firstWords: ["但是只有一个有用。"]))
    }

    @Test func everyLanguageCueWritesHasItsWords() {
        for language in CueLanguage.allCases where !["ar", "th"].contains(language.locale.language.languageCode?.identifier ?? "") {
            #expect(!DashPunctuation.forLanguage(language.locale.language).connectors.isEmpty, "\(language)")
        }
    }
}
