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
        // Cuts keep 0.12 s each side: a 0.6 s cut was a 0.84 s silence, a 0.25 s cut a 0.49 s one.
        let found = CleanUpAnalyzer.suggestions(silences: [TimeSpan(start: 1, end: 1.6), TimeSpan(start: 4, end: 4.25)], transcript: nil)
        #expect(found.map(\.kind) == [.pause, .pause])
        #expect(found[0].isSure)
        #expect(found[0].title == "Long pause")
        #expect(!found[1].isSure)
        #expect(found[1].title == "Short pause")
        #expect(found[1].note == "May be intentional, for emphasis")
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

    @Test func segmentOnlyTimingNeverRemovesAWholePhraseForOneFiller() {
        let estimated = ["um", "today", "I", "want", "to", "talk"].map {
            TimedWord(text: $0, start: 1, end: 4, isEstimated: true)
        }
        let transcript = TakeTranscript(words: estimated, languageCode: "en")
        let found = CleanUpAnalyzer.suggestions(silences: [TimeSpan(start: 5, end: 6)], transcript: transcript)
        #expect(found.map(\.kind) == [.pause])
        #expect(found[0].span == TimeSpan(start: 5, end: 6))
    }

    @Test func pausesHeardOverABackgroundAreListedButNeverMarked() throws {
        let detection = PauseDetection(hearing: .overBackgroundSound, pauses: [
            PauseDetection.Pause(cut: TimeSpan(start: 1.12, end: 1.88), silence: TimeSpan(start: 1, end: 2), isClear: true),
            PauseDetection.Pause(cut: TimeSpan(start: 4.25, end: 5.25), silence: TimeSpan(start: 4, end: 5.5), isClear: false),
            PauseDetection.Pause(cut: TimeSpan(start: 8.25, end: 8.35), silence: TimeSpan(start: 8, end: 8.6), isClear: false),
        ])
        let found = CleanUpAnalyzer.findings(pauses: detection, transcript: nil)
        #expect(found.pauseHearing == .overBackgroundSound)
        #expect(found.suggestions.map(\.isMarkedByDefault) == [true, false, false])
        let long = found.suggestions[1]
        #expect(long.hearing == .overBackgroundSound)
        #expect(long.silence == TimeSpan(start: 4, end: 5.5))
        #expect(!long.isSure)
        #expect(long.title == "Long pause")
        #expect(long.note == "Listen first · none is marked")
        #expect(found.suggestions[2].title == "Short pause")
        // A heard pause survives a draft's save and reopening; one saved before keeps none.
        let again = try JSONDecoder().decode(CleanUpSuggestion.self, from: JSONEncoder().encode(long))
        #expect(again == long)
        #expect(found.suggestions[0].hearing == nil && found.suggestions[0].silence == nil)
    }

    @Test func aSoftVoicesPausesSaySo() {
        let detection = PauseDetection(hearing: .softVoice, pauses: [
            PauseDetection.Pause(cut: TimeSpan(start: 4.25, end: 5.25), silence: TimeSpan(start: 4, end: 5.5), isClear: false),
        ])
        let found = CleanUpAnalyzer.findings(pauses: detection, transcript: nil)
        #expect(found.suggestions.map(\.hearing) == [.softVoice])
        #expect(found.suggestions.allSatisfy { !$0.isMarkedByDefault })
    }

    @Test func reanalysingANoisyTakeLeavesWhatWasDecided() {
        // The creator removed a pause and kept another; listening again, now over background sound, finds them a little moved.
        var removed = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 1.12, end: 1.88), confidence: 0.95)
        removed.status = .removed
        var kept = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 6.12, end: 6.88), confidence: 0.95)
        kept.status = .kept
        let heard = CleanUpAnalyzer.findings(pauses: PauseDetection(hearing: .overBackgroundSound, pauses: [
            PauseDetection.Pause(cut: TimeSpan(start: 1.25, end: 1.75), silence: TimeSpan(start: 1, end: 2), isClear: false),
            PauseDetection.Pause(cut: TimeSpan(start: 6.25, end: 6.75), silence: TimeSpan(start: 6, end: 7), isClear: false),
            PauseDetection.Pause(cut: TimeSpan(start: 9.25, end: 9.75), silence: TimeSpan(start: 9, end: 10), isClear: false),
        ]), transcript: nil)
        let merged = CleanUpAnalyzer.merged(heard.suggestions, into: [removed, kept])
        #expect(merged[0] == removed && merged[1] == kept)
        #expect(merged.count == 3)
        #expect(merged[2].hearing == .overBackgroundSound)
    }

    @Test func oldEditsKeepWhatWasKept() throws {
        let json = #"{"id":"6E0E6D3C-2B0B-4E47-9C3B-0B7E4A1F2C11","kind":"pause","span":{"start":1,"end":2},"confidence":1,"isKept":true}"#
        let decoded = try JSONDecoder().decode(CleanUpSuggestion.self, from: Data(json.utf8))
        #expect(decoded.status == .kept)
        let again = try JSONDecoder().decode(CleanUpSuggestion.self, from: JSONEncoder().encode(decoded))
        #expect(again == decoded)
    }
}
