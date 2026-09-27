//
//  UsagePolicyTests.swift
//  Cue StudioTests
//

import Testing
@testable import Cue_Studio

@Suite("UsagePolicy")
struct UsagePolicyTests {
    @Test func freePlanGetsFiveCleanExports() {
        #expect(UsagePolicy.cleanExportLimit(for: .free) == 5)
    }

    @Test func proPlansExportCleanWithoutLimit() {
        #expect(UsagePolicy.cleanExportLimit(for: .subscriber) == nil)
        #expect(UsagePolicy.cleanExportLimit(for: .lifetime) == nil)
    }
}
