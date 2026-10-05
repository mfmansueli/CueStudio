//
//  OutputLanguageCheckTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// What the model wrote has to be in the language it was asked for, or it never replaces the creator's words.
@Suite("OutputLanguageCheck")
struct OutputLanguageCheckTests {
    private let portuguese = "Esses são três hábitos que mudaram as minhas manhãs. Primeiro, eu bebo um copo de água antes de pegar no celular. Segundo, eu anoto uma coisa que quero terminar hoje."
    private let english = "Here are three habits that changed my mornings. First, I drink a glass of water before I touch my phone. Second, I write down one thing I want to finish today."

    @Test func aTextInTheExpectedLanguagePasses() {
        #expect(OutputLanguageCheck.isPlausible(portuguese, in: .portugueseBrazil))
        #expect(OutputLanguageCheck.isPlausible(english, in: .english))
    }

    /// A model told to polish Portuguese answers in English: refused.
    @Test func aTextClearlyInAnotherLanguageIsRefused() {
        #expect(!OutputLanguageCheck.isPlausible(english, in: .portugueseBrazil))
        #expect(!OutputLanguageCheck.isPlausible(portuguese, in: .english))
    }

    /// A translation handed back untouched is not a translation.
    @Test func aTranslationThatCameBackInTheSourceLanguageIsRefused() {
        #expect(!OutputLanguageCheck.isPlausible(portuguese, in: .german))
    }

    @Test func aShortTextSaysNothingAndPasses() {
        #expect(OutputLanguageCheck.isPlausible("Here are three habits.", in: .portugueseBrazil))
        #expect(OutputLanguageCheck.isPlausible("", in: .english))
    }

    @Test func cuesAreNotSpoken() {
        #expect(OutputLanguageCheck.isPlausible("[pause] [smile] [look at camera]", in: .japanese))
    }

    @Test func aMixedScriptKeepsItsMainLanguage() {
        let mixed = "Hey guys welcome back. Hoje eu vou mostrar três hábitos que mudaram as minhas manhãs. Esses hábitos são simples e qualquer pessoa consegue fazer todos os dias."
        #expect(OutputLanguageCheck.isPlausible(mixed, in: .portugueseBrazil))
    }

    @Test func closeRelativesPassForEachOther() {
        let danish = "Det er tre vaner der har ændret mine morgener. Først drikker jeg et glas vand, før jeg rører min telefon. Dernæst skriver jeg en ting ned."
        #expect(OutputLanguageCheck.isPlausible(danish, in: .norwegian))
        #expect(OutputLanguageCheck.isPlausible(danish, in: .danish))
    }

    @Test func languagesWrittenWithoutSpacesAreCheckedByLetters() {
        let japanese = "朝の習慣を三つ紹介します。まず、スマホを見る前に水を一杯飲みます。次に、今日終わらせたいことを一つ書き出します。そして十分間歩きます。"
        #expect(OutputLanguageCheck.isPlausible(japanese, in: .japanese))
        #expect(!OutputLanguageCheck.isPlausible(japanese, in: .portugueseBrazil))
    }

    /// Traditional characters where Simplified was asked (and the other way) aren't what was asked for.
    @Test func chineseKeepsItsWritingSystem() {
        let traditional = "這是改變我早晨的三個習慣。第一，我在看手機之前先喝一杯水。第二，我寫下今天想完成的一件事。第三，我散步十分鐘，不聽音樂，也不聽播客。"
        #expect(OutputLanguageCheck.isPlausible(traditional, in: .chineseTraditional))
        #expect(!OutputLanguageCheck.isPlausible(traditional, in: .english))
    }
}
