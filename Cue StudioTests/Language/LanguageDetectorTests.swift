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

    // MARK: - Writing systems and the five newer languages

    /// Natural Language names Traditional and Simplified Chinese apart; reduced to "zh" a Traditional
    /// script was taken for Simplified, heard by the Simplified recognizer and written in the wrong characters.
    @Test func traditionalChineseIsNotTakenForSimplified() {
        #expect(LanguageDetector.language(in: "這是改變我早晨的三個習慣。第一，我在看手機之前先喝一杯水。") == .chineseTraditional)
        #expect(LanguageDetector.language(in: "这是改变我早晨的三个习惯。第一，我在看手机之前先喝一杯水。") == .chineseSimplified)
        let traditional = LanguageDetector.dominantLanguage(in: "這是改變我早晨的三個習慣。第一，我在看手機之前先喝一杯水。")
        #expect(traditional?.languageCode?.identifier == "zh" && traditional?.script?.identifier == "Hant")
    }

    @Test func aChineseLeanSettlesTextBothWritingSystemsShare() {
        // Clear Traditional text stays Traditional whatever the iPhone's Chinese is.
        let text = "我今天很高興，因為我們終於完成了這個影片，謝謝你們一直以來的支持。"
        #expect(LanguageDetector.language(in: text, preferring: ["zh-Hans-CN"]) == .chineseTraditional)
    }

    @Test func theNewerLanguagesAreTold() {
        #expect(LanguageDetector.language(in: "Dit zijn drie gewoontes die mijn ochtenden hebben veranderd. Eerst drink ik een glas water.") == .dutch)
        #expect(LanguageDetector.language(in: "Det här är tre vanor som har förändrat mina morgnar. Först dricker jag ett glas vatten.") == .swedish)
        #expect(LanguageDetector.language(in: "Det er tre vaner der har ændret mine morgener. Først drikker jeg et glas vand, før jeg rører min telefon.") == .danish)
        #expect(LanguageDetector.language(in: "Dette er tre vaner som endret morgenene mine. Først drikker jeg et glass vann før jeg tar på telefonen.") == .norwegian)
    }

    @Test func portugueseAndSpanishKeepTheirLanguageWhateverTheRegion() {
        // Natural Language tells the language, not the country: pt-PT and es-MX text are still Portuguese and Spanish.
        #expect(LanguageDetector.language(in: "Estes são três hábitos que mudaram as minhas manhãs. Primeiro, bebo um copo de água antes de pegar no telemóvel.") == .portugueseBrazil)
        #expect(LanguageDetector.language(in: "Estos son tres hábitos que cambiaron mis mañanas. Primero, tomo un vaso de agua antes de agarrar el celular.") == .spanish)
    }
}
