//
//  WritingScriptTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Which scripts words are written in, and which script libraries a font picker offers: only those of the words being styled
/// and of the creator's languages, never one for a creator who writes only Latin.
@Suite("Writing scripts and the libraries offered")
struct WritingScriptTests {
    @Test func theScriptsOfAText() {
        #expect(WritingScript.scripts(in: "Day 1 of my trip").isEmpty)
        #expect(WritingScript.scripts(in: "Ngày đầu tiên của chuyến đi").isEmpty)
        #expect(WritingScript.scripts(in: "Привет мир שלום").isEmpty)
        #expect(WritingScript.scripts(in: "Day 1 の朝") == [.japanese])
        #expect(WritingScript.scripts(in: "여행 첫날 아침") == [.korean])
        #expect(WritingScript.scripts(in: "اليوم الأول") == [.arabic])
        #expect(WritingScript.scripts(in: "पहला दिन") == [.devanagari])
        #expect(WritingScript.scripts(in: "วันแรก") == [.thai])
        #expect(WritingScript.scripts(in: "Hi مرحبا then สวัสดี") == [.arabic, .thai])
    }

    @Test func chineseCharactersAreReadByTheCreatorsLanguages() {
        // Kana makes it Japanese, whatever the creator writes.
        #expect(WritingScript.scripts(in: "東京へ", han: .chineseTraditional) == [.japanese])
        // Without kana, the creator's languages decide.
        #expect(WritingScript.scripts(in: "東京") == [.chineseSimplified])
        #expect(WritingScript.scripts(in: "東京", han: .japanese) == [.japanese])
        #expect(WritingScript.scripts(in: "這是第一天", han: .chineseTraditional) == [.chineseTraditional])
        #expect(WritingScript.hanReading(for: [.portugueseBrazil, .japanese]) == .japanese)
        #expect(WritingScript.hanReading(for: [.chineseTraditional, .japanese]) == .chineseTraditional)
        #expect(WritingScript.hanReading(for: [.english]) == .chineseSimplified)
        #expect(WritingScript.chineseSimplified.contains("字".unicodeScalars.first!))
        #expect(!WritingScript.korean.contains("字".unicodeScalars.first!))
    }

    @Test func aCreatorInLatinLanguagesIsOfferedNoLibrary() {
        for language in CueLanguage.allCases where WritingScript.of(language) == nil {
            let offered = ScriptLibraryOffer.scripts(
                styling: "Day 1 of my trip · Tiếng Việt", captionLanguage: language, scriptLanguage: language, interfaceLanguage: language
            )
            #expect(offered.isEmpty, "\(language)")
        }
        #expect(ScriptLibraryOffer.scripts(styling: "", captionLanguage: nil, scriptLanguage: nil, interfaceLanguage: .english).isEmpty)
    }

    @Test func theWordsBeingStyledBringTheirScriptBesideTheLatinOnes() {
        // A Portuguese creator who typed one Japanese caption: Japanese, while styling it.
        #expect(ScriptLibraryOffer.scripts(
            styling: "旅のはじまり", captionLanguage: .portugueseBrazil, scriptLanguage: .portugueseBrazil, interfaceLanguage: .portugueseBrazil
        ) == [.japanese])
        #expect(ScriptLibraryOffer.scripts(
            styling: "Olá", captionLanguage: .portugueseBrazil, scriptLanguage: .portugueseBrazil, interfaceLanguage: .portugueseBrazil
        ).isEmpty)
    }

    @Test func theCreatorsLanguagesBringTheirScriptsTheWordsFirst() {
        #expect(ScriptLibraryOffer.scripts(styling: "Hello", captionLanguage: .japanese, scriptLanguage: nil, interfaceLanguage: .english) == [.japanese])
        #expect(ScriptLibraryOffer.scripts(styling: "Hello", captionLanguage: nil, scriptLanguage: .hindi, interfaceLanguage: .english) == [.devanagari])
        #expect(ScriptLibraryOffer.scripts(styling: "Hello", captionLanguage: nil, scriptLanguage: nil, interfaceLanguage: .arabic) == [.arabic])
        #expect(ScriptLibraryOffer.scripts(
            styling: "สวัสดี", captionLanguage: .korean, scriptLanguage: .chineseTraditional, interfaceLanguage: .english
        ) == [.thai, .korean, .chineseTraditional])
        // Chinese characters in a Japanese creator's caption are Japanese.
        #expect(ScriptLibraryOffer.scripts(styling: "東京", captionLanguage: .japanese, scriptLanguage: nil, interfaceLanguage: .english) == [.japanese])
    }

    @Test func everyLanguageOfCueWithAScriptHasALibrary() {
        let scripts = Set(CueLanguage.allCases.compactMap(WritingScript.of))
        #expect(scripts == Set(WritingScript.allCases))
    }
}
