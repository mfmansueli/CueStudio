//
//  WritingProgressEstimateTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The percentage while Apple Intelligence writes a script is an estimate (the model never says how long the script will be): it climbs while the
/// model reads the request, moves with the words, slows past the words expected, never goes backwards when the script is written again or
/// lengthened, and says 100% only once the script is there.
@Suite("Writing progress estimate")
struct WritingProgressEstimateTests {
    private let expected = 150

    /// A first draft that went out at 10 s and has `words` so far.
    private func drafted(_ words: Int) -> WritingProgressEstimate {
        var estimate = WritingProgressEstimate(expectedWords: expected)
        estimate.record(.drafting, at: 10)
        estimate.record(.wrote(words: words), at: 12)
        return estimate
    }

    @Test func nothingIsWrittenBeforeTheRequestGoesOut() {
        let estimate = WritingProgressEstimate(expectedWords: expected)
        #expect(estimate.fraction(at: 100) == 0)
    }

    @Test func whileTheModelReadsTheRequestItClimbsToFivePercentInTwoSeconds() {
        var estimate = WritingProgressEstimate(expectedWords: expected)
        estimate.record(.drafting, at: 10)
        #expect(estimate.fraction(at: 10) == 0)
        #expect(abs(estimate.fraction(at: 11) - 0.025) < 1e-9)
        #expect(abs(estimate.fraction(at: 12) - WritingProgressEstimate.preparing) < 1e-9)
        #expect(abs(estimate.fraction(at: 30) - WritingProgressEstimate.preparing) < 1e-9, "it waits there for the words")
    }

    @Test func theFirstDraftMovesWithItsWords() {
        // Half the expected words: halfway through the draft's span (5% → 85%).
        #expect(abs(drafted(75).fraction(at: 12) - 0.45) < 1e-9)
        #expect(drafted(1).fraction(at: 12) > WritingProgressEstimate.preparing)
        #expect(drafted(100).fraction(at: 12) > drafted(75).fraction(at: 12))
    }

    @Test func aDraftLongerThanExpectedSlowsButNeverStopsOrArrives() {
        let atExpected = drafted(expected).fraction(at: 12)
        let longer = drafted(expected * 2).fraction(at: 12)
        let muchLonger = drafted(expected * 4).fraction(at: 12)
        #expect(atExpected > 0.75 && atExpected < 0.8)
        #expect(longer > atExpected && muchLonger > longer)
        #expect(muchLonger <= WritingProgressEstimate.draftEnd)
    }

    @Test func theShareOfTheWordsIsContinuousRisingAndBelowOne() {
        var last = -1.0
        for words in stride(from: 0, through: expected * 3, by: 1) {
            let share = WritingProgressEstimate.share(words: words, of: expected)
            #expect(share > last, "\(words) words")
            #expect(share < 1, "\(words) words")
            // No jump at the knee (or anywhere): one word moves it by at most one word's worth.
            if last >= 0 { #expect(share - last <= 1.0 / Double(expected) + 1e-9, "\(words) words") }
            last = share
        }
    }

    @Test func aDraftWrittenAgainNeverTakesItBack() {
        var estimate = drafted(120)
        let before = estimate.fraction(at: 20)
        // A broken voice rule: the same script, once more, from its first word.
        estimate.record(.drafting, at: 20)
        #expect(estimate.fraction(at: 20) == before)
        estimate.record(.wrote(words: 5), at: 21)
        #expect(estimate.fraction(at: 21) >= before)
        estimate.record(.wrote(words: 150), at: 25)
        let after = estimate.fraction(at: 25)
        #expect(after > before)
        #expect(after < WritingProgressEstimate.ceiling)
    }

    @Test func eachExtraRoundMovesLessAndNoneReachesTheCeiling() {
        var estimate = drafted(150)
        var time: TimeInterval = 20
        var last = estimate.fraction(at: time)
        var lastStep = Double.infinity
        for _ in 0..<6 {
            time += 5
            estimate.record(.drafting, at: time)
            estimate.record(.wrote(words: expected * 3), at: time + 1)
            let now = estimate.fraction(at: time + 1)
            #expect(now > last)
            #expect(now - last < lastStep)
            #expect(now < WritingProgressEstimate.ceiling)
            lastStep = now - last
            last = now
        }
    }

    @Test func lengtheningMovesBlockByBlock() {
        var estimate = drafted(60)
        let base = estimate.fraction(at: 20)
        estimate.record(.lengthening(done: 0, of: 3), at: 20)
        #expect(estimate.fraction(at: 20) == base)
        estimate.record(.lengthening(done: 1, of: 3), at: 23)
        let one = estimate.fraction(at: 23)
        estimate.record(.lengthening(done: 3, of: 3), at: 29)
        let all = estimate.fraction(at: 29)
        #expect(one > base && all > one)
        let filled = base + (WritingProgressEstimate.ceiling - base) * WritingProgressEstimate.roundShare
        #expect(abs(all - filled) < 1e-9)
    }

    @Test func fewerWordsInALaterLookDontTakeItBack() {
        var estimate = drafted(100)
        let before = estimate.fraction(at: 12)
        estimate.record(.wrote(words: 40), at: 13)
        #expect(estimate.fraction(at: 13) == before)
    }

    @Test func onlyTheFinishedScriptIsOneHundredPercent() {
        var estimate = drafted(expected * 10)
        #expect(estimate.fraction(at: 12) < 1)
        estimate.finish()
        #expect(estimate.fraction(at: 12) == 1)
        #expect(estimate.isFinished)
        estimate.record(.drafting, at: 13)
        #expect(estimate.fraction(at: 14) == 1, "nothing after the end changes it")
    }

    @Test func wordsWithoutADraftStillStartIt() {
        var estimate = WritingProgressEstimate(expectedWords: expected)
        estimate.record(.wrote(words: 75), at: 5)
        #expect(abs(estimate.fraction(at: 5) - 0.45) < 1e-9)
    }

    @Test func noWordsExpectedIsStillAnEstimate() {
        var estimate = WritingProgressEstimate(expectedWords: 0)
        #expect(estimate.expectedWords == 1)
        estimate.record(.wrote(words: 3), at: 1)
        let fraction = estimate.fraction(at: 1)
        #expect(fraction > 0 && fraction <= WritingProgressEstimate.draftEnd)
    }
}
