//
//  BestTakeReasonTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// Why Cue picks a take: only what the takes' lengths can tell.
@Suite("BestTakeReason")
struct BestTakeReasonTests {
    private func takes(_ durations: [TimeInterval]) -> [Take] {
        let script = UUID()
        return durations.enumerated().map { index, duration in
            var take = TestData.take(scriptID: script, number: index + 1)
            take.duration = duration
            return take
        }
    }

    @Test func aTakeInsideTheIdealRangeThatRunsTheScriptAndIsClosestSaysAllThree() {
        let all = takes([12, 58, 75])
        let reasons = BestTakeReason.reasons(for: all[1], among: all, expectedDuration: 55, idealRange: 30...60)
        #expect(reasons == [.fitsPlatform(duration: 58), .readWholeScript, .closestToScript])
    }

    @Test func aTakeThatStoppedEarlyIsNotSaidToHaveReadTheScript() {
        let all = takes([10, 55])
        let reasons = BestTakeReason.reasons(for: all[0], among: all, expectedDuration: 55, idealRange: 30...60)
        #expect(!reasons.contains(.readWholeScript) && !reasons.contains(.closestToScript))
    }

    @Test func outsideTheRangeThereIsNoFitReason() {
        let all = takes([40, 90])
        let reasons = BestTakeReason.reasons(for: all[1], among: all, expectedDuration: 80, idealRange: 30...60)
        #expect(!reasons.contains { if case .fitsPlatform = $0 { true } else { false } })
    }

    @Test func theProposalIsIdentifiedByItsPick() {
        let all = takes([30, 31])
        let proposal = BestTakeProposal(takes: all, best: all[1], reasons: [], platformLabel: "TikTok", ideal: 15...60)
        #expect(proposal.id == all[1].id)
    }
}
