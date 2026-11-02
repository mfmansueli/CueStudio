//
//  CatchphraseRotationTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// At most three catchphrases a script, taking turns (the owner's B10, 02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md` §11, A9).
/// Measured before (01/11/2026): all five went in every request, and "Bora lá" opened 7 of 9 scripts.
@MainActor
struct CatchphraseRotationTests {
    private let five = ["Bora lá", "Sem desculpa", "Partiu treino", "Foco no processo", "Tamo junto"]

    @Test func eachScriptGetsAtMostThreeAndNoneTwice() {
        for turn in 0..<12 {
            let offered = CatchphraseRotation.phrases(five, at: turn)
            #expect(offered.count == 3 && Set(offered).count == 3, "turn \(turn): \(offered)")
        }
    }

    @Test func sixScriptsInARowOfferEveryOneAndNoneEveryTime() {
        let offered = (0..<6).map { CatchphraseRotation.phrases(five, at: $0) }
        #expect(Set(offered.flatMap { $0 }) == Set(five))
        for phrase in five {
            let times = offered.filter { $0.contains(phrase) }.count
            #expect(times < 6 && times >= 3, "\(phrase) is offered \(times) times in 6")
        }
        #expect(Set(offered[0] + offered[1]) == Set(five), "two in a row already cover all five")
    }

    @Test func threeOrFewerAlwaysGoWhole() {
        #expect(CatchphraseRotation.phrases(Array(five.prefix(3)), at: 7) == Array(five.prefix(3)))
        #expect(CatchphraseRotation.phrases([], at: 2).isEmpty)
        #expect(!CatchphraseRotation.rotates(Array(five.prefix(3))) && CatchphraseRotation.rotates(five))
    }

    @Test func theTurnIsKeptAndMovesOnOnlyWhenTheyRotate() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.profile.phrases = five
        let first = profile.nextCatchphrases
        profile.advanceCatchphraseTurn()
        #expect(profile.nextCatchphrases != first)
        #expect(CreatorProfileService(defaults: defaults.defaults).catchphraseTurn == 1, "kept across launches")
        profile.profile.phrases = Array(five.prefix(2))
        profile.advanceCatchphraseTurn()
        #expect(profile.catchphraseTurn == 1, "two phrases don't take turns")
    }

    @Test func theRequestCarriesTheTurnsPhrases() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let profile = CreatorProfileService(defaults: defaults.defaults)
        profile.saveVoiceSetup(niches: [.fitness], vocabulary: .simple, sounds: [.energetic])
        profile.profile.phrases = five
        let factory = ScriptRequestFactory(rules: TestData.rulesService(), profile: profile, scriptLanguage: nil, interfaceLanguage: .english)
        let request = factory.request(idea: "Treino de 10 minutos em casa", platform: .tiktok, format: nil)
        #expect(request.voice?.phrases == ["Bora lá", "Sem desculpa", "Partiu treino"])
        #expect(ScriptPromptBuilder.instructions(for: request).contains("“Bora lá”, “Sem desculpa”, “Partiu treino”"))
        #expect(!ScriptPromptBuilder.instructions(for: request).contains("Tamo junto"))
        #expect(ScriptPromptBuilder.brief(for: profile.profile, phrases: profile.nextCatchphrases).text.contains("“Bora lá”, “Sem desculpa”, “Partiu treino”"))
    }
}
