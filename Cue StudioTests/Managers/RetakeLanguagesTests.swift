//
//  RetakeLanguagesTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Clean up › Words' repetitions in every language Cue captions (E4, owner 07/11/2026: "registrar os idiomas testados com fala
/// real"). The words are real: FLEURS readings by people, heard by the iPhone's recognizer (`heard-captions.json`). The repetition
/// is put together: the reader starts the script's first line, stops after a few words and says the whole reading again, the
/// second time with what the recognizer heard the second reader say for the same opening where it differs. No recording here
/// is a person really repeating a line; that is said wherever these results are reported (DESIGN_PROJECT §49).
struct RetakeLanguagesTests {
    private struct Heard: Decodable { let readings: [Reading] }
    private struct Reading: Decodable { let name: String; let words: [[Value]] }
    private struct Manifest: Decodable { let samples: [Sample] }
    private struct Sample: Decodable { let language: String; let file: String; let script: String }
    private enum Value: Decodable {
        case text(String), number(Double), flag(Bool)
        init(from decoder: Decoder) throws {
            let value = try decoder.singleValueContainer()
            if let flag = try? value.decode(Bool.self) {
                self = .flag(flag)
            } else if let number = try? value.decode(Double.self) {
                self = .number(number)
            } else {
                self = .text(try value.decode(String.self))
            }
        }
    }

    private final class BundleToken {}

    private static func timed(_ reading: Reading) -> [TimedWord] {
        reading.words.compactMap { values in
            guard values.count >= 3, case .text(let text) = values[0], case .number(let start) = values[1], case .number(let end) = values[2]
            else { return nil }
            return TimedWord(text: text, start: start, end: end)
        }
    }

    private static func load() throws -> (readings: [String: [TimedWord]], scripts: [String: (language: String, script: String)]) {
        let bundle = Bundle(for: BundleToken.self)
        let heardURL = try #require(bundle.url(forResource: "heard-captions", withExtension: "json"))
        let manifestURL = try #require(bundle.url(forResource: "human-speech", withExtension: "json"))
        let heard = try JSONDecoder().decode(Heard.self, from: Data(contentsOf: heardURL))
        let manifest = try JSONDecoder().decode(Manifest.self, from: Data(contentsOf: manifestURL))
        var readings: [String: [TimedWord]] = [:]
        for reading in heard.readings where reading.name.hasPrefix("human-") { readings[reading.name] = timed(reading) }
        var scripts: [String: (String, String)] = [:]
        for sample in manifest.samples { scripts[sample.file] = (sample.language, sample.script) }
        return (readings, scripts)
    }

    /// The reading with a false start: its first second and a half of words (at least five; Japanese and Chinese come back a
    /// character at a time), half a second of quiet, then all of it again.
    private static func withFalseStart(_ words: [TimedWord]) -> [TimedWord] {
        let begin = words.first?.start ?? 0
        let reach = max(5, words.firstIndex { $0.end - begin >= 1.5 }.map { $0 + 1 } ?? words.count)
        let first = Array(words.prefix(reach))
        let restart = (first.last?.end ?? 0) + 0.5
        let shift = restart - (words.first?.start ?? 0)
        return first + words.map { TimedWord(text: $0.text, start: $0.start + shift, end: $0.end + shift) }
    }

    @Test func aFalseStartIsFoundInEveryLanguageWithRealHeardWords() throws {
        let (readings, scripts) = try Self.load()
        var found: [String: Int] = [:]
        var tried: [String: Int] = [:]
        var misses: [String] = []
        for (name, words) in readings.sorted(by: { $0.key < $1.key }) {
            guard let (language, script) = scripts[name], words.count >= 8 else { continue }
            tried[language, default: 0] += 1
            let take = Self.withFalseStart(words)
            let tries = ScriptRetakeDetector.suggestions(in: take, script: script)
            if tries.count == 2, tries.first?.attempt?.count == 2 {
                found[language, default: 0] += 1
            } else {
                let line = ScriptRetakeDetector.lines(in: script).first?.keys.prefix(6).joined(separator: "|") ?? "-"
                let heard = words.prefix(8).map { WordTokenizer.key($0.text) }.joined(separator: "|")
                misses.append("\(name) tries=\(tries.count)\n  script: \(line)\n  heard:  \(heard)")
            }
        }
        let report = tried.keys.sorted().map { "\($0) \(found[$0] ?? 0)/\(tried[$0] ?? 0)" }.joined(separator: ", ")
        if let folder = ProcessInfo.processInfo.environment["CUE_RETAKE_REPORT"] {
            try? (report + "\n" + misses.joined(separator: "\n")).write(toFile: folder, atomically: true, encoding: .utf8)
        }
        // Measured 08/11/2026 (62 of 80): a reading the detector misses is one whose opening the recognizer heard with two words
        // wrong or more ("Giancarlo Fisichella" as "garlo ficella"); missed, nothing is cut. Floors so a change can't lose ground.
        let total = found.values.reduce(0, +)
        #expect(total >= 62, "\(report)")
        for language in tried.keys { #expect((found[language] ?? 0) >= 1, "\(language): \(report)") }
    }
}
