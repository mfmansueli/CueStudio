//
//  BestTakeSuggesterTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("BestTakeSuggester")
struct BestTakeSuggesterTests {
    private func take(_ number: Int, seconds: TimeInterval, minutesAgo: Double = 0) -> Take {
        var take = TestData.take(scriptID: nil, number: number, recordedAt: TestData.now.addingTimeInterval(-minutesAgo * 60))
        take.duration = seconds
        return take
    }

    @Test func picksTheTakeClosestToTheScriptInsideTheIdealRange() {
        let takes = [take(1, seconds: 58), take(2, seconds: 71), take(3, seconds: 64)]
        #expect(BestTakeSuggester.suggestion(among: takes, expectedDuration: 65, idealRange: 60...90)?.number == 3)
    }

    @Test func takesThatStoppedEarlyAreSkipped() {
        let takes = [take(1, seconds: 20), take(2, seconds: 95)]
        #expect(BestTakeSuggester.suggestion(among: takes, expectedDuration: 70, idealRange: 60...90)?.number == 2)
    }

    @Test func newerWinsATie() {
        let takes = [take(1, seconds: 64, minutesAgo: 10), take(2, seconds: 64, minutesAgo: 1)]
        #expect(BestTakeSuggester.suggestion(among: takes, expectedDuration: 64, idealRange: 60...90)?.number == 2)
    }

    @Test func oneTakeHasNothingToCompare() {
        #expect(BestTakeSuggester.suggestion(among: [take(1, seconds: 60)], expectedDuration: 60, idealRange: 60...90) == nil)
    }
}
