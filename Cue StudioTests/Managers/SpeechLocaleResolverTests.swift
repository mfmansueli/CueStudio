//
//  SpeechLocaleResolverTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("SpeechLocaleResolver")
struct SpeechLocaleResolverTests {
    private func identifiers(_ locales: [Locale]) -> [String] {
        locales.map { $0.identifier(.bcp47) }
    }

    @Test func voiceFollowingLanguageWinsOverTheScript() {
        #expect(SpeechLanguageRequest.resolve(voiceFollowing: .language(.english), scriptLanguage: .portugueseBrazil) == .language(.english))
        #expect(SpeechLanguageRequest.resolve(voiceFollowing: .sameAsScript, scriptLanguage: .portugueseBrazil) == .language(.portugueseBrazil))
        #expect(SpeechLanguageRequest.resolve(voiceFollowing: .sameAsScript, scriptLanguage: nil) == .detectFromScript)
    }

    /// The creator's case: an Italian iPhone, a Portuguese script. Brazilian Portuguese, never
    /// Italian, and never the interface's English.
    @Test func portugueseOnAnItalianIPhoneListensInBrazilianPortuguese() {
        let picked = SpeechLocaleResolver.candidates(
            for: .language(.portugueseBrazil), detectedLanguageCode: nil,
            preferredLanguages: ["it-IT", "en-US"], current: Locale(identifier: "it_IT")
        )
        #expect(identifiers(picked) == ["pt-BR"])
        let detected = SpeechLocaleResolver.candidates(
            for: .detectFromScript, detectedLanguageCode: "pt",
            preferredLanguages: ["it-IT", "en-US"], current: Locale(identifier: "it_IT")
        )
        #expect(identifiers(detected).first == "pt-BR")
        #expect(!identifiers(detected).contains { $0.hasPrefix("it") || $0.hasPrefix("en") })
    }

    @Test func pickedLanguagesUseTheCreatorsRegionWhenTheyHaveOne() {
        let english = SpeechLocaleResolver.candidates(
            for: .language(.english), detectedLanguageCode: nil, preferredLanguages: ["en-GB", "pt-BR"]
        )
        #expect(identifiers(english) == ["en-GB", "en-US"])
        let brazilian = SpeechLocaleResolver.candidates(
            for: .language(.portugueseBrazil), detectedLanguageCode: nil, preferredLanguages: ["pt-PT"]
        )
        #expect(identifiers(brazilian) == ["pt-BR"])
    }

    /// Scripts without a language keep what Voice Following always did: the creator's region
    /// first, then the language itself.
    @Test func detectedScriptsKeepTheOriginalOrder() {
        let english = SpeechLocaleResolver.candidates(
            for: .detectFromScript, detectedLanguageCode: "en", preferredLanguages: ["en-GB", "pt-BR"]
        )
        #expect(identifiers(english) == ["en-GB", "en-US", "en"])
        let portuguese = SpeechLocaleResolver.candidates(
            for: .detectFromScript, detectedLanguageCode: "pt", preferredLanguages: ["pt-BR", "en-US"]
        )
        #expect(identifiers(portuguese) == ["pt-BR", "pt"])
    }

    @Test func withoutALanguageTheDevicesIsTried() {
        let candidates = SpeechLocaleResolver.candidates(
            for: .detectFromScript, detectedLanguageCode: nil, preferredLanguages: ["en-US"], current: Locale(identifier: "fr_FR")
        )
        #expect(identifiers(candidates) == ["fr-FR"])
    }

    @Test func requestsNameTheirLanguage() {
        #expect(SpeechLocaleResolver.language(for: .language(.thai), detectedLanguageCode: nil) == .thai)
        #expect(SpeechLocaleResolver.language(for: .detectFromScript, detectedLanguageCode: "ja") == .japanese)
        #expect(SpeechLocaleResolver.language(for: .detectFromScript, detectedLanguageCode: nil) == nil)
    }

    @Test func detectsTheScriptsLanguage() {
        #expect(SpeechLocaleResolver.detectedLanguageCode(in: "Bom dia, pessoal! Hoje eu vou mostrar como gravar melhor.") == "pt")
        #expect(SpeechLocaleResolver.detectedLanguageCode(in: "Good morning everyone, today I'll show you how to record better.") == "en")
    }
}
