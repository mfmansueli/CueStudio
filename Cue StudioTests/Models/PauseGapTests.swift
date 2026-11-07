//
//  PauseGapTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Gap left" (D8): Natural is the cut every pause had before; Tight and Relaxed move both ends by the same amount; a pause
/// shorter than the gap isn't cut (never made longer); what was removed stays as it was cut.
@Suite("Pause gap")
struct PauseGapTests {
    /// A 1.2 s silence from 4.0 to 5.2 s, as the detector reports it (its padding kept on each side).
    private let pause = CleanUpSuggestion(
        kind: .pause, span: TimeSpan(start: 4.0 + SilenceDetector.padding, end: 5.2 - SilenceDetector.padding), confidence: 0.9
    )

    @Test func theThreeGaps() {
        #expect(PauseGap.tight.seconds == 0.12)
        #expect(PauseGap.natural.seconds == 0.24)
        #expect(PauseGap.relaxed.seconds == 0.40)
        #expect(PauseGap.allCases.map(\.rawValue) == ["tight", "natural", "relaxed"])
    }

    @Test func naturalIsTodaysCut() {
        #expect(pause.cut(leaving: .natural) == pause.span)
    }

    @Test func eachGapLeavesItsSilenceHalfOnEachSide() throws {
        for gap in PauseGap.allCases {
            let cut = try #require(pause.cut(leaving: gap))
            let left = (cut.start - pause.silence.start) + (pause.silence.end - cut.end)
            #expect(abs(left - gap.seconds) < 0.000_1)
            #expect(abs((cut.start - pause.silence.start) - (pause.silence.end - cut.end)) < 0.000_1)
        }
    }

    @Test func aPauseShorterThanTheGapIsNotCut() {
        // 0.45 s of silence: Relaxed would leave 0.40 and cut 0.05, under the minimum.
        let short = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 1.12, end: 1.33), confidence: 0.5)
        #expect(short.cut(leaving: .relaxed) == nil)
        #expect(short.cut(leaving: .tight) != nil)
    }

    @Test func theEndOfTheRecordingIsNeverPassed() throws {
        let last = CleanUpSuggestion(kind: .pause, span: TimeSpan(start: 20.72, end: 21.6), confidence: 0.9)
        let cut = try #require(last.cut(leaving: .tight, recordingLength: 21.6))
        #expect(cut.end <= 21.6)
    }

    @Test func whatWasRemovedStaysAsItWasCut() {
        var removed = pause
        removed.status = .removed
        removed.removedSpan = pause.cut(leaving: .tight)
        #expect(removed.cut(leaving: .relaxed) == pause.cut(leaving: .tight))
    }

    @Test func wordsAreCutAsHeard() {
        let filler = CleanUpSuggestion(kind: .filler, span: TimeSpan(start: 2, end: 2.3), text: "um", confidence: 0.9)
        #expect(filler.cut(leaving: .tight) == filler.span)
        #expect(filler.cut(leaving: .relaxed) == filler.span)
    }

    @Test func anUnknownGapReadsAsNatural() throws {
        let json = #"{"pauseGap": "enormous"}"#
        struct Holder: Decodable { let pauseGap: PauseGap }
        #expect(try JSONDecoder().decode(Holder.self, from: Data(json.utf8)).pauseGap == .natural)
    }
}
