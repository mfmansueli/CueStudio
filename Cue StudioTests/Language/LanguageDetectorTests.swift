//
//  LanguageDetectorTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("LanguageDetector")
struct LanguageDetectorTests {
    @Test func tellsTheLanguageOfAScript() {
        #expect(LanguageDetector.language(in: "Esses são três hábitos que mudaram as minhas manhãs.") == .portugueseBrazil)
        #expect(LanguageDetector.language(in: "Here are three habits that changed my mornings.") == .english)
        #expect(LanguageDetector.language(in: "朝の習慣を三つ紹介します。") == .japanese)
    }

    @Test func anEnglishPhraseInAPortugueseScriptDoesntMakeItEnglish() {
        let script = "Hey guys welcome back. Hoje eu vou mostrar três hábitos que mudaram as minhas manhãs. "
            + "Esses hábitos são simples e qualquer pessoa consegue fazer todos os dias."
        #expect(LanguageDetector.dominantLanguageCode(in: script) == "pt")
        #expect(LanguageDetector.dominantLanguageCode(in: script, preferring: ["pt-BR"]) == "pt")
    }

    @Test func aPortuguesePhraseInAnEnglishScriptDoesntMakeItPortuguese() {
        let script = "Here are three habits that changed my mornings. Muito obrigado por assistir. "
            + "They are simple and anyone can do them every single day."
        #expect(LanguageDetector.dominantLanguageCode(in: script) == "en")
    }

    @Test func theCreatorsLanguagesNeverOutvoteClearText() {
        #expect(LanguageDetector.dominantLanguageCode(in: "Here are three habits that changed my mornings.", preferring: ["pt-BR"]) == "en")
    }

    @Test func anEnglishIPhoneDoesntMakeAPortugueseScriptEnglish() {
        let script = "Olá! Hoje eu trouxe dicas incríveis de Paris. Coisas pra fazer e comer. Comece com uma caminhada no Museu de Orsay. Explore os cafés charmosos."
        #expect(LanguageDetector.dominantLanguageCode(in: script, preferring: ["en-US"]) == "pt")
        #expect(LanguageDetector.dominantLanguageCode(in: "Olá, tudo bem com você hoje?", preferring: ["en-US"]) == "pt")
    }

    @Test func aPhraseIsForeignOnlyWhenItIsClearlyAnotherLanguage() {
        #expect(LanguageDetector.isForeign(["Welcome", "back", "to", "my", "channel"], to: "pt"))
        #expect(!LanguageDetector.isForeign(["Bem", "vindos", "ao", "meu", "canal"], to: "pt"))
        // One word says nothing about its language.
        #expect(!LanguageDetector.isForeign(["growth"], to: "pt"))
    }

    @Test func cuesDontCount() {
        #expect(LanguageDetector.dominantLanguageCode(in: "[pause] [smile]") == nil)
    }
}
