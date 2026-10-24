//
//  CaptionReplayTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The captions a creator sees, rebuilt from what an iPhone heard: every recording the device suites play (`SpeechSample`, the
/// system voice and four people a language) as `CaptionTranscriber` heard it on a device (`heard-captions.json`, written from a
/// `CaptionSpeechTests` run by `tools/speech/heard_fixture.py`), turned into lines by `CaptionBuilder` with the reading's script,
/// as a take is. Runs anywhere, in a second, so the script's part (`ScriptSpelling`) can be changed and measured without a phone.
///
/// Measured against the script, which is what was read: the share of words (letters in Japanese, Chinese, Thai and Korean) the
/// lines get wrong, before the script lends its spelling and after. The script may only ever help. And when the voice says
/// something else than the script, the lines show what was said: a phrase of the script swapped for another never appears.
@Suite("Captions rebuilt from what an iPhone heard")
struct CaptionReplayTests {
    private struct Heard: Decodable {
        let heardOn: String
        let readings: [Reading]
    }

    private struct Reading: Decodable {
        let name: String
        let words: [[HeardValue]]
    }

    /// A word as stored: text, start, end, estimated.
    private enum HeardValue: Decodable {
        case text(String), time(Double), flag(Bool)

        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let flag = try? value.decode(Bool.self) {
                self = .flag(flag)
            } else if let time = try? value.decode(Double.self) {
                self = .time(time)
            } else {
                self = .text(try value.decode(String.self))
            }
        }
    }

    private struct Replay {
        let sample: SpeechSample
        let heard: [CaptionWord]
    }

    private final class BundleToken {}

    private static func replays() throws -> (heardOn: String, replays: [Replay]) {
        let url = try #require(Bundle(for: BundleToken.self).url(forResource: "heard-captions", withExtension: "json"))
        let stored = try JSONDecoder().decode(Heard.self, from: Data(contentsOf: url))
        let samples = try CueLanguage.allCases.map(SpeechSample.synthetic(of:)) + SpeechSample.human()
        let replays = try stored.readings.map { reading in
            let sample = try #require(samples.first { $0.name == reading.name }, "\(reading.name) isn't a recording the suites play")
            let words = reading.words.compactMap { values -> TimedWord? in
                guard values.count == 4, case .text(let text) = values[0], case .time(let start) = values[1],
                      case .time(let end) = values[2], case .flag(let estimated) = values[3] else { return nil }
                return TimedWord(text: text, start: start, end: end, isEstimated: estimated)
            }
            // Each reading was one result, heard before `SettledLastWord` made a last word heard twice one.
            let heard = SettledLastWord.applied(to: words).map {
                CaptionWord(text: $0.text, start: $0.start, end: $0.end, isEstimated: $0.isEstimated)
            }
            return Replay(sample: sample, heard: heard)
        }
        return (stored.heardOn, replays)
    }

    /// What the creator sees: the words of the lines.
    private static func shown(_ heard: [CaptionWord], script: String, language: CueLanguage) -> [String] {
        CaptionBuilder.captions(heard: heard, script: script, language: language).flatMap { $0.words.map(\.text) }
    }

    @Test func theScriptOnlyEverHelps() throws {
        let (heardOn, replays) = try Self.replays()
        #expect(replays.count == CueLanguage.allCases.count * 5)
        var rows: [CueLanguage: [(raw: Double, shown: Double, isPerson: Bool)]] = [:]
        var lines: [String] = []
        for replay in replays {
            let sample = replay.sample
            let raw = CaptionErrorRate.of(replay.heard.map(\.text), against: sample.script, language: sample.language)
            let words = Self.shown(replay.heard, script: sample.script, language: sample.language)
            let shown = CaptionErrorRate.of(words, against: sample.script, language: sample.language)
            lines.append("\(sample.name) \(Int((shown * 100).rounded()))%: \(CaptionText.joined(words))")
            rows[sample.language, default: []].append((raw, shown, sample.voice == .human))
            #expect(shown <= raw + 0.0001, "\(sample.label): \(Int(raw * 100))% wrong as heard, \(Int(shown * 100))% on screen")
        }
        var report = ["CAPTION REPLAY of what \(heardOn) heard (wrong words, letters for ja/zh/th/ko): heard → on screen"]
        for language in CueLanguage.allCases {
            let all = rows[language] ?? []
            let system = all.filter { !$0.isPerson }
            let people = all.filter(\.isPerson)
            func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
            func mean(_ values: [Double]) -> Double { values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count) }
            report.append(
                "\(language.rawValue): system \(system.map { "\(percent($0.raw)) → \(percent($0.shown))" }.joined())"
                    + " · people \(percent(mean(people.map(\.raw)))) → \(percent(mean(people.map(\.shown))))"
                    + " (worst \(percent(people.map(\.shown).max() ?? 0)))"
            )
        }
        let everyone = rows.values.flatMap { $0 }.filter(\.isPerson)
        let heardByPeople = everyone.map(\.raw).reduce(0, +) / Double(max(1, everyone.count))
        let shownToPeople = everyone.map(\.shown).reduce(0, +) / Double(max(1, everyone.count))
        report.append("all people: \(heardByPeople) → \(shownToPeople)")
        // 9.0% of people's words heard wrong, 6.5% on screen with the script's numbers and names (7.4% before them).
        #expect(shownToPeople <= 0.065, "people's captions get \(Int((shownToPeople * 100).rounded()))% of the words wrong")
        report += lines
        print(report.joined(separator: "\n"))
        // `TEST_RUNNER_CUE_REPLAY_REPORT=<file>` keeps the table, which a simulator's console doesn't show.
        if let path = ProcessInfo.processInfo.environment["CUE_REPLAY_REPORT"] {
            try report.joined(separator: "\n").write(toFile: path, atomically: true, encoding: .utf8)
        }
    }

    /// The creator said the sentence as it is, but the script has another phrase there: the lines keep what was said. Every
    /// reading against scripts with one to four of its words swapped, every third word along, for a phrase as long from each
    /// other reading in its language (10,700 scripts). 22 still show a word that wasn't said, all from the near-miss rule: a
    /// word one or two letters from what was heard ("المحطة" for "المحيط", "Winken" for "denken"), which fixes far more
    /// mishearings than it costs. A change may only lower the count.
    @Test func aPhraseTheVoiceDidntSayNeverAppears() throws {
        let (_, replays) = try Self.replays()
        var scripts = 0
        var shownUnsaid: [String] = []
        for replay in replays {
            let sample = replay.sample
            let language = sample.language
            let words = CaptionText.words(in: sample.script, language: language)
            let said = Set(words.map(WordAlignment.key))
            let heardKeys = Set(replay.heard.map { WordAlignment.key($0.text) })
            for other in replays where other.sample.language == language && other.sample.name != sample.name {
                let otherWords = CaptionText.words(in: other.sample.script, language: language)
                for length in 1...4 {
                    for from in stride(from: 1, to: max(1, words.count - length - 1), by: 3) {
                        let otherFrom = min(from, max(0, otherWords.count - length))
                        guard otherWords.count >= otherFrom + length, words.count > from + length else { continue }
                        let phrase = Array(otherWords[otherFrom..<(otherFrom + length)])
                        let phraseKeys = Set(phrase.map(WordAlignment.key))
                        let script = CaptionText.joined(Array(words[..<from]) + phrase + Array(words[(from + length)...]))
                        scripts += 1
                        let added = Self.shown(replay.heard, script: script, language: language).filter { word in
                            let key = WordAlignment.key(word)
                            return !key.isEmpty && phraseKeys.contains(key) && !said.contains(key) && !heardKeys.contains(key)
                        }
                        if !added.isEmpty { shownUnsaid.append("\(sample.label) +\(added) for “\(phrase.joined(separator: " "))”") }
                    }
                }
            }
        }
        #expect(scripts == 10_700)
        #expect(shownUnsaid.count <= 22, "\(shownUnsaid.count) scripts show words the voice didn't say: \(shownUnsaid.joined(separator: "; "))")
    }
}
