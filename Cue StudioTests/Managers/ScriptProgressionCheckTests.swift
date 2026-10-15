//
//  ScriptProgressionCheckTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Where a script stops moving forward (`ScriptProgressionCheck`). The cases are the baseline run's own (pt-BR "cinco passos" told in four,
/// "três erros" told with "Depois" and "E por último").
@Suite("Script progression")
struct ScriptProgressionCheckTests {
    @Test func aCountPromisedAndToldIsKept() {
        let text = """
        Fala, galera! Três erros que estragam sua pele de manhã.

        Primeiro, usar produtos muito fortes. Depois, esquecer de limpar bem. E, por último, dormir com produtos ativos.

        Comente qual erro você faz!
        """
        #expect(ScriptProgressionCheck.defects(in: text, idea: "3 erros que estragam sua pele de manhã", language: "pt").isEmpty)
    }

    @Test func fiveStepsToldInFourIsADefectInTheBody() {
        let text = """
        Dá pra ficar pronta em cinco minutos, sério. Mostro uma maquiagem completa em cinco passos rápidos.

        Primeiro, aplico uma cor base leve. Depois, um tom discreto nos olhos. Em seguida, reforço os contornos. Por fim, um brilho discreto.

        Comente qual produto você usa!
        """
        let defects = ScriptProgressionCheck.defects(in: text, idea: "Mostre uma maquiagem completa em cinco passos rápidos.", language: "pt")
        #expect(defects.map(\.kind) == [.unkeptCount])
        #expect(defects.first?.detail.contains("5") == true && defects.first?.detail.contains("4") == true)
    }

    @Test func aMeasureIsNoPromise() {
        #expect(ScriptProgressionCheck.promisedCount(in: "A maquiagem de 5 minutos para o dia a dia", language: "pt") == nil)
        #expect(ScriptProgressionCheck.promisedCount(in: "Cómo armar un fondo de 500 dólares en 90 días", language: "es") == nil)
        #expect(ScriptProgressionCheck.promisedCount(in: "Tres errores al abrir una tienda pequeña", language: "es") == 3)
        #expect(ScriptProgressionCheck.promisedCount(in: "3 mistakes that ruin your home workouts", language: "en") == 3)
    }

    @Test func aScriptThatDoesntCountItsPointsIsNotJudged() {
        let text = "Rest days make you stronger.\n\nYour muscles rebuild when you rest. Sleep does the rest.\n\nSave this."
        #expect(ScriptProgressionCheck.defects(in: text, idea: "3 reasons rest days make you stronger", language: "en").isEmpty)
    }

    @Test func aBlockThatSaysTheLastOneAgainIsAnEcho() {
        let text = """
        Drink a glass of water as soon as you wake up, before coffee and before your phone.

        Drink a glass of water as soon as you wake up, before coffee and before your phone. It really helps.

        Save this.
        """
        let kinds = ScriptProgressionCheck.defects(in: text, idea: nil, language: "en").map(\.kind)
        #expect(kinds.contains(.echo))
    }

    @Test func aNumberedListCounts() {
        #expect(ScriptProgressionCheck.toldCount(in: ["1. Clean first. 2. Protect the neck. 3. Moisturize."], language: "pt") == 3)
    }
}
