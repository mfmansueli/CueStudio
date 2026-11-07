//
//  NoisyRoomPauseTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// D16, measured: Clean Up's pauses on the noisy-room corpus (`NoisyRoomCorpus`: FLEURS readings in pt, en and es with made
/// consonants, breaths and backgrounds), with the fixed silence level as before ("today") and with the level that follows the
/// background ("now"). Each condition prints its row (`D16 |`, also attached to the result) and holds the owner's conditions: no pause marked to go
/// on speech that the fixed level wouldn't have marked, no cut into a word beyond 100 ms, quiet rooms exactly as before, and an
/// honest "too much background sound" where the voice doesn't stand clear. Changed in the code and measured here, not heard: the
/// iPhone still has to confirm it by ear.
@Suite("Clean Up in a noisy room (D16)")
struct NoisyRoomPauseTests {
    @Test(arguments: NoisyRoomCorpus.conditions)
    func condition(_ condition: NoisyRoomCorpus.Condition) throws {
        var today = Score()
        var now = Score()
        var hearings: [PauseHearing] = []
        var sameAsToday = true
        for language in NoisyRoomCorpus.languages.indices {
            let take = try NoisyRoomCorpus.take(condition, language: language)
            let levels = AudioLevelReader.levels(ofSamples: take.mixed, sampleRate: NoisyRoomCorpus.rate)
            let before = SilenceDetector.silences(levels: levels, interval: 0.05)
            let found = CleanUpAnalyzer.findings(pauses: SilenceDetector.pauses(levels: levels, interval: 0.05), transcript: nil)
            hearings.append(found.pauseHearing)
            sameAsToday = sameAsToday && found.suggestions.map(\.span) == before
            today.add(CleanUpAnalyzer.suggestions(silences: before, transcript: nil), truth: take.truth)
            now.add(found.suggestions, truth: take.truth)
            // Only a pause heard clearly is marked to go.
            #expect(found.suggestions.allSatisfy { !$0.isMarkedByDefault || $0.hearing == nil })
        }
        // The row, in the log and attached to the result (`xcrun xcresulttool export attachments`).
        let row = "D16 | \(condition.name) | today: \(today.row) | now [\(hearings.map(\.rawValue).joined(separator: ", "))]: \(now.row)"
        print(row)
        Attachment.record(row, named: "D16 \(condition.name).txt")

        // Never more speech marked to go than the fixed level marked.
        #expect(now.markedOnWords <= today.markedOnWords)
        // No listed cut takes a word: at most one with a stretch of speech in it, never more than 100 ms of words.
        #expect(now.speechFlagged <= 1)
        #expect(now.maxWordMilliseconds <= 100)
        if hearings.allSatisfy({ $0 == .clear }) { #expect(sameAsToday, "A quiet room hears its pauses exactly as before") }

        switch (condition.noise, condition.snr, condition.gains) {
        case (.none, _, [0]):
            #expect(hearings.allSatisfy { $0 == .clear })
        case (.fan, 20, [0]), (.fan, 12, [0]), (.street, 15, [0]):
            // The fixed level hears nothing over the background; the moved one finds most of the pauses, none marked.
            #expect(hearings.allSatisfy { $0 == .overBackgroundSound })
            #expect(today.found == 0)
            #expect(now.found >= 10)
            #expect(now.marked == 0)
        case (.fan, 6, _), (.street, 8, _), (.music, _, _):
            #expect(hearings.allSatisfy { $0 == .tooMuchBackgroundSound })
            #expect(now.listed == 0)
        case (.none, _, _), (.fan, 12, [-20]):
            // A soft voice: the fixed level takes quiet words for pauses (and marks them); the level under the voice doesn't.
            #expect(hearings.allSatisfy { $0 == .softVoice })
            #expect(now.speechFlagged == 0)
            #expect(now.marked == 0)
            #expect(now.found >= 10)
        default:
            #expect(now.found >= 10)
            #expect(now.marked == 0)
        }
    }

    /// How a set of suggestions fares against the truth, over the three languages.
    struct Score {
        /// Pauses of the truth at least as long as the panel lists by default (none of their frames a word).
        var truth = 0
        /// Pauses listed by default, found truth pauses, and pauses marked to go.
        var listed = 0
        var found = 0
        var marked = 0
        /// Listed cuts with at least 50 ms of speech in them; the most word (speech and consonants) in one cut.
        var speechFlagged = 0
        var maxWordMilliseconds = 0
        var consonantMilliseconds = 0
        var breathMilliseconds = 0
        /// Marked cuts with any word frame in them.
        var markedOnWords = 0

        var row: String {
            "\(listed) listed, \(found)/\(truth) found, \(speechFlagged) on speech, \(maxWordMilliseconds) ms max in a word, "
                + "\(consonantMilliseconds) ms of consonants, \(breathMilliseconds) ms of breath, \(marked) marked (\(markedOnWords) on words)"
        }

        mutating func add(_ suggestions: [CleanUpSuggestion], truth frames: [NoisyRoomCorpus.Frame]) {
            let pauses = Self.pauses(in: frames)
            let shown = suggestions.filter { $0.kind == .pause && SilenceDetector.silenceLength(of: $0) >= NoisyRoomCorpus.listedFrom - 0.001 }
            truth += pauses.count
            listed += shown.count
            found += pauses.filter { pause in shown.contains { $0.span.overlaps(pause) } }.count
            for suggestion in shown {
                let first = max(0, Int(suggestion.span.start * 100))
                let last = min(frames.count, Int((suggestion.span.end * 100).rounded(.up)))
                let inside = first < last ? Array(frames[first..<last]) : []
                let words = inside.filter(\.isWord).count
                var run = 0
                var longest = 0
                for kind in inside {
                    run = kind == .speech ? run + 1 : 0
                    longest = max(longest, run)
                }
                if longest >= 5 { speechFlagged += 1 }
                maxWordMilliseconds = max(maxWordMilliseconds, words * 10)
                consonantMilliseconds += inside.filter { $0 == .consonant }.count * 10
                breathMilliseconds += inside.filter { $0 == .breath }.count * 10
                if suggestion.isMarkedByDefault {
                    marked += 1
                    if words > 0 { markedOnWords += 1 }
                }
            }
        }

        private static func pauses(in frames: [NoisyRoomCorpus.Frame]) -> [TimeSpan] {
            var result: [TimeSpan] = []
            var index = 0
            while index < frames.count {
                guard !frames[index].isWord else { index += 1; continue }
                var end = index
                while end < frames.count, !frames[end].isWord { end += 1 }
                if Double(end - index) / 100 >= NoisyRoomCorpus.listedFrom { result.append(TimeSpan(start: Double(index) / 100, end: Double(end) / 100)) }
                index = end
            }
            return result
        }
    }
}
