//
//  MixedLanguageMergeTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// A take whose script has an English opening and a Portuguese rest is heard in both languages, and
/// each stretch comes from the recognizer whose words line up with the script.
@Suite("Mixed language captions")
struct MixedLanguageMergeTests {
    private static let english = ["hey", "everyone", "welcome", "back", "to", "the", "channel"]
    private static let portuguese = ["hoje", "eu", "vou", "mostrar", "três", "hábitos", "para", "você"]

    private let reading = ScriptLanguageRuns.Reading(
        words: english + portuguese,
        runs: [.init(code: "en", words: 0..<7), .init(code: "pt", words: 7..<15)]
    )

    /// One word per half second from `start`.
    private func said(_ words: [String], from start: TimeInterval) -> [TimedWord] {
        words.enumerated().map { index, word in
            TimedWord(text: word, start: start + Double(index) * 0.5, end: start + Double(index) * 0.5 + 0.4)
        }
    }

    /// The English recognizer hears the English opening, then nonsense for the Portuguese; the
    /// Portuguese recognizer does the opposite. The English opening is 0–3.5 s, the rest 4 s on.
    private var englishEars: MixedLanguageMerge.Heard {
        .init(code: "en", words: said(Self.english, from: 0) + said(["whoa", "you", "boss", "must", "tray", "us", "ab", "etch"], from: 4))
    }

    private var portugueseEars: MixedLanguageMerge.Heard {
        .init(code: "pt", words: said(["rei", "ever", "uan", "bequei", "tu", "de", "chanel"], from: 0) + said(Self.portuguese, from: 4))
    }

    @Test func eachStretchComesFromTheRecognizerThatHeardItInItsLanguage() {
        for primary in ["pt", "en"] {
            let merged = MixedLanguageMerge.merge([portugueseEars, englishEars], primary: primary, reading: reading)
            #expect(merged.map(\.text) == Self.english + Self.portuguese, "main recognizer: \(primary)")
            #expect(merged.map(\.start) == merged.map(\.start).sorted())
        }
    }

    @Test func theTimesAreTheOnesTheVoiceGave() {
        let merged = MixedLanguageMerge.merge([portugueseEars, englishEars], primary: "pt", reading: reading)
        #expect(merged.first?.start == 0)
        #expect(merged.last?.end == 4 + 7 * 0.5 + 0.4)
    }

    @Test func aTakeWithOneRecognizerIsThatRecognizersWords() {
        let only = MixedLanguageMerge.merge([portugueseEars], primary: "pt", reading: reading)
        #expect(only == portugueseEars.words)
    }

    @Test func aTakeNothingLinesUpWithIsTheMainRecognizersAsBefore() {
        let improvised = ScriptLanguageRuns.Reading(
            words: ["completely", "different", "sentence", "about", "cooking", "pasta", "tonight"],
            runs: [.init(code: "en", words: 0..<3), .init(code: "pt", words: 3..<7)]
        )
        let merged = MixedLanguageMerge.merge([portugueseEars, englishEars], primary: "pt", reading: improvised)
        #expect(merged == portugueseEars.words)
    }

    @Test func aStretchNobodyReadStaysWithTheMainRecognizer() {
        // The English opening was skipped: only the Portuguese lines up, so only it is decided.
        let skipped = [
            MixedLanguageMerge.Heard(code: "pt", words: said(["rei", "ever", "uan"], from: 0) + said(Self.portuguese, from: 4)),
            MixedLanguageMerge.Heard(code: "en", words: said(["hey", "there"], from: 0) + said(["whoa", "you", "boss", "must"], from: 4)),
        ]
        let merged = MixedLanguageMerge.merge(skipped, primary: "pt", reading: reading)
        #expect(merged.map(\.text) == ["rei", "ever", "uan"] + Self.portuguese)
    }

    @Test func aScriptMisreadAsAnotherLanguageStillGoesToTheRecognizerThatLinesUp() {
        // The second stretch was taken for Spanish; the Portuguese recognizer lines up best, so it wins.
        let doubtful = ScriptLanguageRuns.Reading(
            words: Self.english + Self.portuguese, runs: [.init(code: "en", words: 0..<7), .init(code: "es", words: 7..<15)]
        )
        let spanishEars = MixedLanguageMerge.Heard(code: "es", words: said(["jei", "ever", "guan"], from: 0) + said(["oye", "eu", "voy", "mostrar"], from: 4))
        let merged = MixedLanguageMerge.merge([portugueseEars, englishEars, spanishEars], primary: "pt", reading: doubtful)
        #expect(merged.map(\.text) == Self.english + Self.portuguese)
    }

    @Test func aTranscriptMadeBeforeThisWayOfHearingIsHeardAgain() throws {
        let old = Data(#"{"words":[],"languageCode":"pt"}"#.utf8)
        #expect(try JSONDecoder().decode(CaptionTranscript.self, from: old).isCurrent == false)
        #expect(CaptionTranscript(words: [], languageCode: "pt").isCurrent)
        let saved = try JSONEncoder().encode(CaptionTranscript(words: [], languageCode: "pt"))
        #expect(try JSONDecoder().decode(CaptionTranscript.self, from: saved).isCurrent)
    }
}
