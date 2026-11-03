//
//  IdeaLanguageValidationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("Idea language validation")
struct IdeaLanguageValidationTests {
    private func idea(_ text: String) -> ThemeIdea {
        var idea = ThemeIdea(title: text, kind: "List", length: .minute1, niche: .lifestyle)
        idea.brief = IdeaBrief(subject: text, angle: text, openingLine: text)
        return idea
    }

    @Test func anEnglishIdeaCannotEnterTheJapanesePool() {
        let english = idea("Three simple morning habits that help you start your day with more energy and less stress")
        #expect(throws: ScriptAIError.self) {
            try IdeaBriefReader.validated([english], language: Locale.Language(identifier: "ja"))
        }
    }

    /// What the model did on 5 of 376 titles in Portuguese and Spanish (03/11/2026): the title in English over an angle and opening in Spanish.
    @Test func anEnglishTitleOverASpanishBriefIsLeftOut() throws {
        var english = idea("Seven tasty snack swaps")
        english.brief = IdeaBrief(
            subject: english.title, angle: "Inventa ideas para meriendas fáciles con lo que hay en la despensa",
            openingLine: "Siempre hay una manera sencilla de mejorar las comidas de cada día"
        )
        var spanish = idea("Qué hacer con el pan sobrante del día")
        spanish.brief = IdeaBrief(
            subject: spanish.title, angle: "Cocina tres platos sencillos con el pan que sobra en casa",
            openingLine: "El pan de ayer todavía puede ser la mejor parte de la cena de hoy"
        )
        let valid = try IdeaBriefReader.validated([english, spanish], language: Locale.Language(identifier: "es"))
        #expect(valid.map(\.title) == [spanish.title])
    }

    @Test(arguments: [
        ("Uma rotina de exercícios com tênis usado no dia a dia", "pt"), ("Opinión honesta sobre hacer la maleta ligera", "es"),
        ("Le mythe du café qui coupe la faim", "fr"), ("Top 5 Fehler beim Sparen", "de"), ("冷蔵庫に入れてはいけない野菜", "ja"), ("Skincare", "pt"),
    ])
    func aTitleInItsOwnLanguagePasses(_ title: String, _ language: String) {
        #expect(OutputLanguageCheck.isTitlePlausible(title, in: Locale.Language(identifier: language)))
    }

    @Test func oneWrongLanguageDoesNotDiscardTheValidIdeas() throws {
        let japanese = idea("朝の習慣を少し変えるだけで、一日の始まりを落ち着いて過ごすことができます。まずはゆっくり体を動かしてみましょう。")
        let english = idea("These morning habits help you start your day with more energy and less stress")
        let valid = try IdeaBriefReader.validated([japanese, english], language: Locale.Language(identifier: "ja"))
        #expect(valid.map(\.title) == [japanese.title])
    }
}
