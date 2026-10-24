//
//  ScriptNamesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The names of a script, the words the script may lend even when the recognizer wrote others for them.
@Suite("Script names")
struct ScriptNamesTests {
    @Test func peoplePlacesAndBrandsAreNames() {
        let names = ScriptNames.keys(
            in: "Giancarlo Fisichella perdeu o controle do carro em Monza. Gravei tudo no iPhone e postei no TikTok.",
            language: .portugueseBrazil
        )
        #expect(names == ["giancarlo", "fisichella", "monza", "iphone", "tiktok"])
    }

    @Test func aWordStartingASentenceAloneIsntAName() {
        #expect(ScriptNames.keys(in: "Hoje vou mostrar três hábitos. Primeiro, eu bebo água.", language: .portugueseBrazil).isEmpty)
        #expect(!ScriptNames.keys(in: "Wenn Sie den Film „Das Vermächtnis“ gesehen haben", language: .german).contains("das"))
    }

    /// German capitalizes its nouns: only a capital inside a word marks a name there.
    @Test func germanNounsArentNames() {
        #expect(ScriptNames.keys(in: "Ich habe das Video mit dem iPhone im Garten gedreht.", language: .german) == ["iphone"])
    }

    @Test func latinLettersInAnotherAlphabetAreNames() {
        #expect(ScriptNames.keys(in: "Scotturb 403 路公共汽车定期发车前往辛特拉 (Sintra)。", language: .chineseSimplified) == ["scotturb", "sintra"])
    }
}
