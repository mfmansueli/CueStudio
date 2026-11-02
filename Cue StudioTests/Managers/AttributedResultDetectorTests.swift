//
//  AttributedResultDetectorTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A result nobody gave, put in the creator's mouth (the owner's B12, 02/11/2026; §11, A11b): 48 sentences labeled by hand in the five languages
/// it reads, half results it must catch and half scenes, routines, advice and hooks it must leave alone.
@MainActor
struct AttributedResultDetectorTests {
    struct Labeled: CustomTestStringConvertible, Sendable {
        let language: String
        let sentence: String
        let isResult: Bool
        var testDescription: String { "\(language) \(isResult ? "result" : "scene"): \(sentence)" }
    }

    nonisolated static let sentences: [Labeled] = [
        // Portuguese
        Labeled(language: "pt-BR", sentence: "Eu perdi 2 quilos em 7 dias.", isResult: true),
        Labeled(language: "pt-BR", sentence: "Em um mês emagreci 5 kg sem academia.", isResult: true),
        Labeled(language: "pt-BR", sentence: "Faturei 10 mil reais no primeiro mês.", isResult: true),
        Labeled(language: "pt-BR", sentence: "Ganhei 3 mil seguidores em uma semana.", isResult: true),
        Labeled(language: "pt-BR", sentence: "Minha produtividade aumentou 40% assim.", isResult: true),
        Labeled(language: "pt-BR", sentence: "Economizei 500 reais só cortando o delivery.", isResult: true),
        Labeled(language: "pt-BR", sentence: "Eu treino três vezes por semana, de manhã.", isResult: false),
        Labeled(language: "pt-BR", sentence: "Perdi três dias de treino naquela semana.", isResult: false),
        Labeled(language: "pt-BR", sentence: "Leva cinco minutos para preparar.", isResult: false),
        Labeled(language: "pt-BR", sentence: "Aqui vão 3 dicas para dormir melhor.", isResult: false),
        Labeled(language: "pt-BR", sentence: "Eu acordo às 6 e tomo um copo de água.", isResult: false),
        Labeled(language: "pt-BR", sentence: "Você pode perder peso sem passar fome.", isResult: false),
        // English
        Labeled(language: "en-US", sentence: "I lost 10 pounds in two weeks.", isResult: true),
        Labeled(language: "en-US", sentence: "I made $5,000 from my first launch.", isResult: true),
        Labeled(language: "en-US", sentence: "My sales went up 30% overnight.", isResult: true),
        Labeled(language: "en-US", sentence: "I gained 2,000 followers in a month.", isResult: true),
        Labeled(language: "en-US", sentence: "I saved 300 dollars by cooking at home.", isResult: true),
        Labeled(language: "en-US", sentence: "I walk 20 minutes after lunch.", isResult: false),
        Labeled(language: "en-US", sentence: "Here are 5 ways to save money.", isResult: false),
        Labeled(language: "en-US", sentence: "I missed three workouts that week.", isResult: false),
        Labeled(language: "en-US", sentence: "It takes ten minutes, twice a day.", isResult: false),
        Labeled(language: "en-US", sentence: "Most people quit after 3 days.", isResult: false),
        // Spanish
        Labeled(language: "es-ES", sentence: "Perdí 4 kilos en un mes.", isResult: true),
        Labeled(language: "es-ES", sentence: "Gané 2.000 euros con mi primer curso.", isResult: true),
        Labeled(language: "es-ES", sentence: "Mi tienda vendió un 50% más.", isResult: true),
        Labeled(language: "es-ES", sentence: "Ahorré 200 euros este mes.", isResult: true),
        Labeled(language: "es-ES", sentence: "Entreno tres veces por semana.", isResult: false),
        Labeled(language: "es-ES", sentence: "Son 5 minutos al día.", isResult: false),
        Labeled(language: "es-ES", sentence: "Te doy 3 consejos para empezar.", isResult: false),
        Labeled(language: "es-ES", sentence: "Me despierto a las 7.", isResult: false),
        // French
        Labeled(language: "fr-FR", sentence: "J'ai perdu 5 kilos en trois semaines.", isResult: true),
        Labeled(language: "fr-FR", sentence: "J'ai gagné 1 000 euros le premier mois.", isResult: true),
        Labeled(language: "fr-FR", sentence: "Mon chiffre a augmenté de 20 %.", isResult: true),
        Labeled(language: "fr-FR", sentence: "J'ai doublé mes abonnés: 4 000 en un mois.", isResult: true),
        Labeled(language: "fr-FR", sentence: "Je cours 30 minutes le matin.", isResult: false),
        Labeled(language: "fr-FR", sentence: "Voici 3 astuces pour mieux dormir.", isResult: false),
        Labeled(language: "fr-FR", sentence: "J'ai raté deux séances cette semaine.", isResult: false),
        Labeled(language: "fr-FR", sentence: "Ça prend cinq minutes.", isResult: false),
        // Italian
        Labeled(language: "it-IT", sentence: "Ho perso 6 chili in un mese.", isResult: true),
        Labeled(language: "it-IT", sentence: "Ho guadagnato 3.000 euro con il mio corso.", isResult: true),
        Labeled(language: "it-IT", sentence: "Ho raddoppiato i clienti: da 10 a 20.", isResult: true),
        Labeled(language: "it-IT", sentence: "Ho risparmiato 150 euro questo mese.", isResult: true),
        Labeled(language: "it-IT", sentence: "Mi alleno tre volte a settimana.", isResult: false),
        Labeled(language: "it-IT", sentence: "Ecco 4 consigli per iniziare.", isResult: false),
        Labeled(language: "it-IT", sentence: "Ci vogliono dieci minuti.", isResult: false),
        Labeled(language: "it-IT", sentence: "Ho saltato due allenamenti.", isResult: false),
        Labeled(language: "pt-BR", sentence: "Eu cheguei a pesar 90 kg e me sentia mal.", isResult: true),
        Labeled(language: "en-US", sentence: "My first client paid me 200 dollars.", isResult: true),
    ]

    @Test(arguments: sentences)
    func readsTheSentenceAsLabeled(_ item: Labeled) {
        let found = AttributedResultDetector.findings(in: item.sentence, language: item.language, request: "Uma ideia sem números")
        #expect(found.isEmpty == !item.isResult)
    }

    @Test func theBatteryIsBalancedAndLargeEnough() {
        #expect(Self.sentences.count >= 40)
        #expect(Self.sentences.filter(\.isResult).count >= 20 && Self.sentences.filter { !$0.isResult }.count >= 20)
    }

    @Test func aNumberTheCreatorGaveIsTheirs() {
        #expect(AttributedResultDetector.findings(in: "Eu perdi 10 quilos assim.", language: "pt-BR", request: "Como eu perdi 10 quilos").isEmpty)
        #expect(!AttributedResultDetector.findings(in: "Eu perdi 12 quilos assim.", language: "pt-BR", request: "Como eu perdi 10 quilos").isEmpty)
    }

    @Test func aLanguageItDoesntReadSaysNothing() {
        #expect(AttributedResultDetector.findings(in: "私は5キロ痩せました。", language: "ja-JP", request: "").isEmpty)
    }

    @Test func aResultThatStaysAfterTheSecondDraftAsksToCheckTheFacts() async throws {
        var calls = 0
        let writing = VoiceCheckedWriting(
            draft: { _, _ in
                calls += 1
                return GeneratedScript(title: "Dieta", text: "Eu desisti da dieta numa terça.\n\nEu perdi 2 quilos em 7 dias.", usedLanguageModel: true)
            },
            isGuardrailRefusal: { _ in false }, report: { _, _ in }
        )
        let request = ScriptRequest(source: .prompt("O dia em que eu desisti da dieta"), platform: .tiktok, voice: nil, targetRange: 30...60,
                                    language: .portugueseBrazil)
        let script = try await writing.write(request)
        #expect(calls == 2, "written once more")
        #expect(script.voiceViolations.contains(.inventedResult))
        #expect(script.needsFactCheck)
    }
}
