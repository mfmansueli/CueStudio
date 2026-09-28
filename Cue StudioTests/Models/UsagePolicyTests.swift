//
//  UsagePolicyTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("UsagePolicy")
struct UsagePolicyTests {
    @Test func freePlanGetsFiveExports() {
        #expect(UsagePolicy.exportLimit(for: .free) == 5)
    }

    @Test func subscribersExportWithoutLimit() {
        #expect(UsagePolicy.exportLimit(for: .subscriber) == nil)
    }
}
