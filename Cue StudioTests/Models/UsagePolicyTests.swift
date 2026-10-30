//
//  UsagePolicyTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("UsagePolicy")
struct UsagePolicyTests {
    @Test func freePlanGetsThreeExports() {
        #expect(UsagePolicy.exportLimit(for: .free) == 3)
    }

    @Test func subscribersExportWithoutLimit() {
        #expect(UsagePolicy.exportLimit(for: .subscriber) == nil)
    }
}
