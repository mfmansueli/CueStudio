//
//  UltraCallBudgetTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The lab's cap: each call is counted before it goes out, none past the limit, and the count is never lowered or reset by another instance.
@MainActor
@Suite("Ultra AI call budget")
struct UltraCallBudgetTests {
    @Test func callsAreCountedUpToTheLimit() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let budget = UltraCallBudget(defaults: defaults.defaults, limit: 3)
        #expect(budget.allows(2))
        #expect(budget.reserve() && budget.reserve())
        #expect(!budget.allows(2) && budget.allows(1))
        #expect(budget.reserve())
        #expect(!budget.reserve())
        #expect(budget.used == 3 && budget.remaining == 0)
    }

    @Test func anotherScreensCountIsReadAgain() {
        let defaults = TestDefaults()
        defer { defaults.tearDown() }
        let lab = UltraCallBudget(defaults: defaults.defaults, limit: 30)
        let scripts = UltraCallBudget(defaults: defaults.defaults, limit: 30)
        #expect(scripts.reserve() && scripts.reserve())
        #expect(lab.reserve())
        #expect(lab.used == 3 && defaults.defaults.integer(forKey: UltraCallBudget.key) == 3)
    }

    @Test func theOwnersLimitIsThirty() {
        #expect(UltraCallBudget.labLimit == 30)
    }
}
