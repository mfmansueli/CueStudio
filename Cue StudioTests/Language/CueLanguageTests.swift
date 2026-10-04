//
//  CueLanguageTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("CueLanguage")
struct CueLanguageTests {
    @Test func offersTheTwentyLanguages() {
        #expect(CueLanguage.allCases.map(\.rawValue) == [
            "en-US", "es-ES", "pt-BR", "fr-FR", "de-DE", "it-IT", "ja-JP", "ko-KR",
            "zh-CN", "hi-IN", "id-ID", "ar-SA", "tr-TR", "th-TH", "vi-VN", "zh-TW", "nl-NL", "sv-SE", "da-DK", "nb-NO",
        ])
    }

    @Test func eachLanguageHasItsOwnIdentifiers() {
        let languages = CueLanguage.allCases
        #expect(Set(languages.map(\.interfaceLocalization)).count == languages.count)
        // Simplified and Traditional Chinese share the ISO code "zh"; everything else has its own.
        #expect(Set(languages.map(\.languageCode)).count == languages.count - 1)
        #expect(Set(languages.map(\.nativeName)).count == languages.count)
    }

    /// The `.lproj` names match the String Catalogs' languages.
    @Test func interfaceLocalizationsAreTheCatalogLanguages() {
        #expect(CueLanguage.allCases.map(\.interfaceLocalization) == [
            "en", "es", "pt-BR", "fr", "de", "it", "ja", "ko", "zh-Hans", "hi", "id", "ar", "tr", "th", "vi", "zh-Hant", "nl", "sv", "da", "nb",
        ])
    }

    @Test func speechLocalesAreTheRegionalOnesAppleLists() {
        #expect(CueLanguage.portugueseBrazil.speechLocale.identifier(.bcp47) == "pt-BR")
        #expect(CueLanguage.chineseSimplified.speechLocale.identifier(.bcp47) == "zh-CN")
        #expect(CueLanguage.arabic.speechLocale.identifier(.bcp47) == "ar-SA")
    }

    @Test func onlyArabicReadsRightToLeft() {
        #expect(CueLanguage.allCases.filter(\.isRightToLeft) == [.arabic])
    }

    @Test func japaneseChineseAndThaiAreWrittenWithoutSpaces() {
        #expect(CueLanguage.allCases.filter(\.writesWithoutSpaces) == [.japanese, .chineseSimplified, .thai, .chineseTraditional])
    }

    @Test func matchesLanguageCodesAndLocalizations() {
        #expect(CueLanguage.matching(languageCode: "pt") == .portugueseBrazil)
        #expect(CueLanguage.matching(languageCode: "pt-PT") == .portugueseBrazil)
        #expect(CueLanguage.matching(languageCode: "zh-Hans") == .chineseSimplified)
        #expect(CueLanguage.matching(languageCode: "zh-Hant") == .chineseTraditional)
        #expect(CueLanguage.matching(languageCode: "zh-TW") == .chineseTraditional)
        #expect(CueLanguage.matching(languageCode: "zh") == .chineseSimplified)
        #expect(CueLanguage.matching(languageCode: "no") == .norwegian)
        #expect(CueLanguage.matching(languageCode: "nl") == .dutch)
        #expect(CueLanguage.matching(languageCode: "ru") == nil)
        #expect(CueLanguage.matching(interfaceLocalization: "zh-Hans") == .chineseSimplified)
        #expect(CueLanguage.matching(interfaceLocalization: "pt-BR") == .portugueseBrazil)
        #expect(CueLanguage.matching(interfaceLocalization: "en") == .english)
    }

    /// Recognition in another variant would be recognition in another language.
    @Test func acceptsOnlyItsOwnVariant() {
        #expect(CueLanguage.portugueseBrazil.accepts(Locale(identifier: "pt-BR")))
        #expect(!CueLanguage.portugueseBrazil.accepts(Locale(identifier: "pt-PT")))
        #expect(CueLanguage.chineseSimplified.accepts(Locale(identifier: "zh-CN")))
        #expect(!CueLanguage.chineseSimplified.accepts(Locale(identifier: "zh-TW")))
        #expect(CueLanguage.chineseTraditional.accepts(Locale(identifier: "zh-TW")))
        #expect(!CueLanguage.chineseTraditional.accepts(Locale(identifier: "zh-CN")))
        #expect(CueLanguage.norwegian.accepts(Locale(identifier: "nb-NO")))
        #expect(!CueLanguage.chineseSimplified.accepts(Locale(identifier: "yue-CN")))
        #expect(CueLanguage.english.accepts(Locale(identifier: "en-GB")))
        #expect(!CueLanguage.english.accepts(Locale(identifier: "es-US")))
    }

    @Test func namesItselfAndInOtherLanguages() {
        #expect(CueLanguage.portugueseBrazil.nativeName == "Português (Brasil)")
        #expect(CueLanguage.portugueseBrazil.name(in: Locale(identifier: "en")) == "Portuguese (Brazil)")
        #expect(CueLanguage.portugueseBrazil.englishName == "Portuguese (Brazil)")
        #expect(CueLanguage.german.name(in: Locale(identifier: "pt-BR")) == "Alemão")
        // Lowercase language names start upper in a list.
        #expect(CueLanguage.spanish.name(in: Locale(identifier: "es")) == "Español")
    }

    @Test func codableAsItsLocale() throws {
        let data = try JSONEncoder().encode([CueLanguage.portugueseBrazil])
        #expect(String(bytes: data, encoding: .utf8) == #"["pt-BR"]"#)
        #expect(try JSONDecoder().decode([CueLanguage].self, from: data) == [.portugueseBrazil])
    }
}
