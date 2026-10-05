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

    // MARK: - Regional variants

    /// The creator's own variant comes from the languages they listed, never from the device's country.
    @Test func theCreatorsVariantComesFromTheirOwnLanguageList() {
        #expect(CueLanguage.english.variant(among: ["it-IT", "en-GB"])?.identifier(.bcp47) == "en-GB")
        #expect(CueLanguage.spanish.variant(among: ["es-MX", "en-US"])?.identifier(.bcp47) == "es-MX")
        #expect(CueLanguage.english.variant(among: ["it-IT"]) == nil)
        #expect(CueLanguage.english.variant(among: []) == nil)
        // A language listed without a region has no variant to keep.
        #expect(CueLanguage.english.variant(among: ["en"]) == nil)
    }

    /// Brazilian Portuguese stays Brazilian unless the language was only read from the text.
    @Test func aVariantCueWritesDifferentlyIsOnlyKeptForALanguageReadFromText() {
        #expect(CueLanguage.portugueseBrazil.variant(among: ["pt-PT"]) == nil)
        #expect(CueLanguage.portugueseBrazil.variant(among: ["pt-PT"], acceptingAnyVariant: true)?.identifier(.bcp47) == "pt-PT")
        #expect(CueLanguage.portugueseBrazil.variant(among: ["pt-BR"])?.identifier(.bcp47) == "pt-BR")
    }

    @Test func chineseVariantsNeverCrossWritingSystems() {
        #expect(CueLanguage.chineseTraditional.variant(among: ["zh-Hans-CN", "zh-Hant-HK"])?.identifier(.bcp47) == "zh-Hant-HK")
        #expect(CueLanguage.chineseTraditional.variant(among: ["zh-Hans-CN"], acceptingAnyVariant: true) == nil)
        #expect(CueLanguage.chineseSimplified.variant(among: ["zh-Hant-TW"], acceptingAnyVariant: true) == nil)
    }

    @Test func matchesALocaleLanguageKeepingTheWritingSystem() {
        #expect(CueLanguage.matching(language: Locale.Language(identifier: "zh-Hant")) == .chineseTraditional)
        #expect(CueLanguage.matching(language: Locale.Language(identifier: "zh-Hans")) == .chineseSimplified)
        #expect(CueLanguage.matching(language: Locale.Language(identifier: "nn")) == .norwegian)
        #expect(CueLanguage.chineseTraditional.chineseScriptIdentifier == "zh-Hant")
        #expect(CueLanguage.english.chineseScriptIdentifier == nil)
    }
}
