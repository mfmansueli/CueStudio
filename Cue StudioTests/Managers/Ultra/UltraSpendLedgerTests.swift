//
//  UltraSpendLedgerTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The lab's record of what Ultra spent on this iPhone: kept across launches, a total that keeps everything when the old entries go, averages of
/// finished requests only, and a fresh start for a new measurement.
@MainActor
@Suite("Ultra AI spend ledger")
struct UltraSpendLedgerTests {
    private func cost(calls: Int, prompt: Int, output: Int) -> UltraCost {
        var cost = UltraCost()
        for _ in 0..<calls {
            cost.add(UltraModelReply(text: "", finishedNormally: true, promptTokens: prompt, outputTokens: output))
        }
        return cost
    }

    @Test func whatWasSpentIsThereAfterALaunch() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let ledger = UltraSpendLedger(defaults: defaults.defaults)
        ledger.record(.script, cost: cost(calls: 3, prompt: 1_000, output: 2_000), finished: true)
        ledger.record(.fit, cost: cost(calls: 1, prompt: 500, output: 1_000), finished: true)
        let again = UltraSpendLedger(defaults: defaults.defaults)
        #expect(again.entries.map(\.kind) == [.script, .fit])
        #expect(again.total.calls == 4 && again.total.inputTokens == 3_500 && again.total.outputTokens == 7_000)
    }

    @Test func nothingWentOutNothingIsRecorded() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let ledger = UltraSpendLedger(defaults: defaults.defaults)
        ledger.record(.script, cost: UltraCost(), finished: false)
        #expect(ledger.entries.isEmpty && ledger.total.calls == 0)
    }

    /// A failed or stopped script spent its calls: in the total, not in what a finished script costs.
    @Test func averagesAreOfFinishedRequestsAndTheTotalOfAll() throws {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let ledger = UltraSpendLedger(defaults: defaults.defaults)
        let small = cost(calls: 3, prompt: 1_000, output: 5_000)
        let big = cost(calls: 4, prompt: 2_000, output: 10_000)
        ledger.record(.script, cost: small, finished: true)
        ledger.record(.script, cost: big, finished: true)
        ledger.record(.script, cost: cost(calls: 1, prompt: 900, output: 2_000), finished: false)
        let scripts = try #require(ledger.summary(of: .script))
        #expect(scripts.count == 2 && scripts.meanCalls == 3.5)
        #expect(abs(scripts.mean - (small.dollars() + big.dollars()) / 2) < 1e-12)
        #expect(abs(scripts.most - big.dollars()) < 1e-12)
        #expect(ledger.summary(of: .fit) == nil)
        #expect(ledger.total.calls == 8)
    }

    @Test func theTotalKeepsWhatTheEntriesLetGo() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let ledger = UltraSpendLedger(defaults: defaults.defaults)
        for _ in 0..<(UltraSpendLedger.keptEntries + 5) {
            ledger.record(.fit, cost: cost(calls: 1, prompt: 10, output: 10), finished: true)
        }
        #expect(ledger.entries.count == UltraSpendLedger.keptEntries)
        #expect(ledger.total.calls == UltraSpendLedger.keptEntries + 5)
    }

    @Test func aNewMeasurementStartsFromNothing() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let ledger = UltraSpendLedger(defaults: defaults.defaults)
        ledger.record(.script, cost: cost(calls: 3, prompt: 1_000, output: 2_000), finished: true)
        ledger.startOver()
        #expect(ledger.entries.isEmpty && ledger.total == UltraCost())
        #expect(UltraSpendLedger(defaults: defaults.defaults).total.calls == 0)
    }
}
