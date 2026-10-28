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

    @Test func oneWrongLanguageDoesNotDiscardTheValidIdeas() throws {
        let japanese = idea("朝の習慣を少し変えるだけで、一日の始まりを落ち着いて過ごすことができます。まずはゆっくり体を動かしてみましょう。")
        let english = idea("These morning habits help you start your day with more energy and less stress")
        let valid = try IdeaBriefReader.validated([japanese, english], language: Locale.Language(identifier: "ja"))
        #expect(valid.map(\.title) == [japanese.title])
    }
}
