//
//  CueLanguageTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("CueLanguage")
struct CueLanguageTests {
    @Test func offersTheFifteenLanguages() {
        #expect(CueLanguage.allCases.map(\.rawValue) == [
            "en", "es", "pt-BR", "fr", "de", "it", "ja", "ko", "zh-Hans", "hi", "id", "ar", "tr", "th", "vi",
        ])
    }

    @Test func eachLanguageHasItsOwnLocale() {
        let locales = CueLanguage.allCases.map(\.localeIdentifier)
        #expect(Set(locales).count == locales.count)
        #expect(CueLanguage.portugueseBrazil.localeIdentifier == "pt-BR")
        #expect(CueLanguage.chineseSimplified.localeIdentifier == "zh-CN")
        for language in CueLanguage.allCases {
            #expect(language.locale.language.languageCode?.identifier == language.languageCode)
        }
    }

    @Test func matchesLocalesAndLanguageCodes() {
        #expect(CueLanguage(identifier: "en_GB") == .english)
        #expect(CueLanguage(identifier: "pt") == .portugueseBrazil)
        #expect(CueLanguage(identifier: "pt-PT") == .portugueseBrazil)
        #expect(CueLanguage(identifier: "zh-Hans-CN") == .chineseSimplified)
        #expect(CueLanguage(identifier: "zh-Hant") == nil)
        #expect(CueLanguage(identifier: "zh-TW") == nil)
        #expect(CueLanguage(identifier: "nl") == nil)
        for language in CueLanguage.allCases {
            #expect(CueLanguage(identifier: language.localeIdentifier) == language)
            #expect(CueLanguage(identifier: language.localizationIdentifier) == language)
        }
    }

    @Test func onlyArabicIsRightToLeft() {
        #expect(CueLanguage.allCases.filter(\.isRightToLeft) == [.arabic])
    }

    @Test func nativeNamesDontDependOnTheInterface() {
        #expect(CueLanguage.portugueseBrazil.nativeName == "Português (Brasil)")
        #expect(CueLanguage.japanese.nativeName == "日本語")
    }

    @Test func scriptDirectionComesFromTheLettersOrTheLanguage() {
        #expect(ScriptDirection.isRightToLeft("مرحبا بكم في القناة"))
        #expect(!ScriptDirection.isRightToLeft("Hello everyone"))
        #expect(!ScriptDirection.isRightToLeft("Olá [pause] مرحبا everyone here"))
        #expect(ScriptDirection.isRightToLeft(TestData.script(text: "Hi", language: .arabic)))
        #expect(!ScriptDirection.isRightToLeft(TestData.script(text: "مرحبا", language: .english)))
    }
}
