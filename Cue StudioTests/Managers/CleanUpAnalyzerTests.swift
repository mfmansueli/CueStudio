//
//  CleanUpAnalyzerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("CleanUpAnalyzer")
struct CleanUpAnalyzerTests {
    /// Words said at the given times, each lasting a quarter second.
    private func said(_ words: [(String, TimeInterval)]) -> [TimedWord] {
        words.map { TimedWord(text: $0.0, start: $0.1, end: $0.1 + 0.25) }
    }

    @Test func longPausesAreSureShortOnesWaitForTheCreator() {
        // Cuts keep 0.15 s each side: a 0.5 s cut was a 0.8 s silence, a 0.25 s cut a 0.55 s one.
        let found = CleanUpAnalyzer.suggestions(silences: [TimeSpan(start: 1, end: 1.5), TimeSpan(start: 4, end: 4.25)], transcript: nil)
        #expect(found.map(\.kind) == [.pause, .pause])
        #expect(found[0].isSure)
        #expect(found[0].title == "Long pause")
        #expect(!found[1].isSure)
        #expect(found[1].title == "Short pause")
        #expect(found[1].note == "May be intentional — for emphasis")
        #expect(found.allSatisfy { $0.status == .pending })
    }

    @Test func theTranscriptAddsFillersAndRetakesInOrder() {
        let words = said([
            ("So", 0), ("um,", 0.25), ("today", 0.5),
            ("The", 3.0), ("best", 3.25), ("wey", 3.5), ("let", 3.75), ("me", 4.0), ("start", 4.25), ("again.", 4.5),
            ("The", 5.5), ("best", 5.75), ("way", 6.0),
        ])
        let transcript = TakeTranscript(words: words, languageCode: "en")
        // A pause inside the retake goes with it; the one before it stays.
        let found = CleanUpAnalyzer.suggestions(silences: [TimeSpan(start: 1, end: 2), TimeSpan(start: 3.3, end: 3.45)], transcript: transcript)
        #expect(found.map(\.kind) == [.filler, .pause, .retake])
        #expect(found[0].title == "“um,”")
        #expect(found[0].isSure)
        #expect(found[2].title == "Possible retake")
        // Retakes always wait for a listen.
        #expect(!found[2].isSure)
    }

    @Test func aNewAnalysisKeepsTheCreatorsDecisions() {
        var kept = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 1, end: 2), confidence: 0.95)
        kept.status = .kept
        let pending = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 5, end: 6), confidence: 0.95)
        let found = [
            CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 1.1, end: 1.9), confidence: 0.95),
            CleanUpSuggestion(kind: .filler, span: TimeSpan(start: 8, end: 8.25), text: "um", confidence: 0.9),
        ]
        let merged = CleanUpAnalyzer.merged(found, into: [kept, pending])
        #expect(merged.map(\.span.start) == [1, 8])
        #expect(merged[0].status == .kept)
        #expect(merged[0].id == kept.id)
    }

    @Test func oldEditsKeepWhatWasKept() throws {
        let json = #"{"id":"6E0E6D3C-2B0B-4E47-9C3B-0B7E4A1F2C11","kind":"pause","span":{"start":1,"end":2},"confidence":1,"isKept":true}"#
        let decoded = try JSONDecoder().decode(CleanUpSuggestion.self, from: Data(json.utf8))
        #expect(decoded.status == .kept)
        let again = try JSONDecoder().decode(CleanUpSuggestion.self, from: JSONEncoder().encode(decoded))
        #expect(again == decoded)
    }
}
