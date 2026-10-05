//
//  VoiceFollowingRobustnessTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// How Voice Following's tracker holds up against the ways people really read: leaving words out,
/// repeating, thinking aloud, skipping ahead, and filler words between the script's words. A
/// deterministic reader (seeded) is run against scripts in several languages and the position the text
/// reaches is compared with where the reader really is.
///
/// This is evidence about the tracker only, on text standing in for a recognizer: it says nothing
/// about how well a device recognizes a language (see `VoiceFollowingSpeechTests`, on a device).
@Suite("Voice Following robustness")
struct VoiceFollowingRobustnessTests {
    private static let english = """
        Here are three habits that changed my mornings. First, I drink a glass of water before I touch my phone. \
        Second, I write down one thing I want to finish today. Third, I walk for ten minutes, no music, no podcasts. \
        Nothing fancy, but it works. If you try only one, try the water. Your brain is thirsty after eight hours of sleep, \
        and the phone can wait. Then, when you write down your one thing, make it small enough to finish before lunch. \
        I used to write ten tasks and finish two. Now I write one and finish it. That is the whole trick.
        """
    private static let portuguese = """
        Esses são três hábitos que mudaram as minhas manhãs. Primeiro, eu bebo um copo de água antes de pegar no celular. \
        Segundo, eu anoto uma coisa que quero terminar hoje. Terceiro, eu caminho por dez minutos, sem música, sem podcast. \
        Nada de mais, mas funciona. Se você tentar só um, tente a água. O seu cérebro está com sede depois de oito horas de sono, \
        e o celular pode esperar. Depois, quando você anotar a sua coisa do dia, faça ela pequena o bastante para terminar antes do almoço. \
        Eu escrevia dez tarefas e terminava duas. Agora eu escrevo uma e termino. Esse é o truque inteiro.
        """
    private static let japanese = "朝の習慣を三つ紹介します。まず、スマホを見る前に水を一杯飲みます。次に、今日終わらせたいことを一つ書き出します。そして、音楽もポッドキャストもなしで十分間歩きます。特別なことではありませんが、効果があります。"

    private static let fillers = ["the", "a", "yes", "uh", "so", "and", "to", "is", "it", "de", "que", "e"]
    private static let asides = [
        "so anyway where was i", "let me check my notes real quick", "okay sorry about that", "wait is the camera still recording",
    ]

    enum Reading: String, CaseIterable {
        case clean, omittingWords, repeatingPhrases, thinkingAloud, skippingAhead, fillerBetweenWords
    }

    /// What one reading came to: how far from the reader the text was, update by update.
    struct Outcome {
        var errors: [Int] = []
        var finalFraction = 0.0

        var aheadP95: Int { Self.percentile(errors.filter { $0 > 0 }, 0.95) }
        var behindP95: Int { Self.percentile(errors.filter { $0 < 0 }.map { -$0 }, 0.95) }

        private static func percentile(_ values: [Int], _ share: Double) -> Int {
            values.isEmpty ? 0 : values.sorted()[min(values.count - 1, Int(Double(values.count) * share))]
        }
    }

    private struct SeededGenerator: RandomNumberGenerator {
        var state: UInt64
        init(_ seed: UInt64) { state = seed &+ 0x9E3779B97F4A7C15 }
        mutating func next() -> UInt64 {
            state &+= 0x9E3779B97F4A7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
            z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
            return z ^ (z >> 31)
        }
    }

    static func read(_ reading: Reading, _ script: String, in language: CueLanguage, seed: UInt64) -> Outcome {
        var random = SeededGenerator(seed &* 7919)
        let spoken = WordTokenizer.words(in: script, language: language).map(\.text)
        let tokens = ScriptWords(text: script, language: language).tokens
        var tracker = ScriptSpeechTracker(words: tokens, language: language)
        let unspaced = language.writesWithoutSpaces
        var heard: [String] = []
        var outcome = Outcome()
        func hear(truth: Int) {
            tracker.hear(unspaced ? heard.suffix(60).joined() : heard.suffix(60).joined(separator: " "))
            outcome.errors.append(tracker.position - truth)
        }
        var index = 0
        var sinceEvent = 0
        while index < spoken.count {
            sinceEvent += 1
            let chance = Double.random(in: 0..<1, using: &random)
            switch reading {
            case .clean: break
            case .omittingWords:
                if chance < 0.15 { index += 1; continue }
            case .repeatingPhrases:
                if sinceEvent > 14, index > 6, chance < 0.2 {
                    heard += spoken[max(0, index - Int.random(in: 4...6, using: &random))..<index]
                    hear(truth: index)
                    sinceEvent = 0
                }
            case .thinkingAloud:
                if sinceEvent > 20, chance < 0.12 {
                    for word in asides.randomElement(using: &random)!.split(separator: " ") {
                        heard.append(String(word))
                        hear(truth: index)
                    }
                    sinceEvent = 0
                }
            case .skippingAhead:
                if sinceEvent > 15, index < spoken.count - 15, chance < 0.12 {
                    index += Int.random(in: 8...14, using: &random)
                    sinceEvent = 0
                    continue
                }
            case .fillerBetweenWords:
                if chance < 0.5 {
                    heard.append(fillers.randomElement(using: &random)!)
                    hear(truth: index)
                    continue
                }
            }
            heard.append(spoken[index])
            index += 1
            hear(truth: index)
        }
        outcome.finalFraction = Double(tracker.position) / Double(max(1, tokens.count))
        return outcome
    }

    private func outcomes(_ reading: Reading, _ script: String, _ language: CueLanguage, seeds: ClosedRange<UInt64> = 1...5) -> [Outcome] {
        seeds.map { Self.read(reading, script, in: language, seed: $0) }
    }

    // MARK: - What has to hold

    @Test(arguments: [(CueLanguage.english, english), (.portugueseBrazil, portuguese), (.japanese, japanese)])
    func everyReadingGetsToTheEndOfTheScript(language: CueLanguage, script: String) {
        for reading in Reading.allCases {
            for outcome in outcomes(reading, script, language, seeds: 1...3) {
                #expect(outcome.finalFraction >= 0.97, "\(language.rawValue) \(reading.rawValue): reached \(outcome.finalFraction)")
            }
        }
    }

    @Test(arguments: [(CueLanguage.english, english), (.portugueseBrazil, portuguese), (.japanese, japanese)])
    func aCleanReadingIsFollowedWithoutLagOrJumpingAhead(language: CueLanguage, script: String) {
        for outcome in outcomes(.clean, script, language, seeds: 1...2) {
            #expect(outcome.aheadP95 == 0 && outcome.behindP95 <= 1, "\(language.rawValue): ahead \(outcome.aheadP95), behind \(outcome.behindP95)")
        }
    }

    /// Filler between the words (the script's own "the", "de", "e") put the text up to 53 words ahead of
    /// the reader before common words counted for less; 95th percentile 47 in English. Now it stays within a few.
    @Test(arguments: [(CueLanguage.english, english), (.portugueseBrazil, portuguese)])
    func fillerBetweenWordsDoesNotRunTheTextAhead(language: CueLanguage, script: String) {
        for outcome in outcomes(.fillerBetweenWords, script, language, seeds: 1...5) {
            #expect(outcome.aheadP95 <= 8, "\(language.rawValue): the text ran \(outcome.aheadP95) words ahead")
        }
    }

    @Test func thinkingAloudAndRepeatingStayCloseToTheReader() {
        for reading in [Reading.thinkingAloud, .repeatingPhrases, .omittingWords] {
            for outcome in outcomes(reading, Self.english, .english) {
                #expect(outcome.aheadP95 <= 8, "\(reading.rawValue): ahead \(outcome.aheadP95)")
                #expect(outcome.behindP95 <= 4, "\(reading.rawValue): behind \(outcome.behindP95)")
            }
        }
    }

    @Test func skippingAheadIsFollowedAndNeverOvershot() {
        for outcome in outcomes(.skippingAhead, Self.portuguese, .portugueseBrazil) {
            #expect(outcome.aheadP95 == 0)
            #expect(outcome.finalFraction >= 0.97)
        }
    }
}
