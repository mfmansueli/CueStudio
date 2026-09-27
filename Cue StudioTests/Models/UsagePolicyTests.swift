//
//  UsagePolicyTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@Suite("UsagePolicy")
struct UsagePolicyTests {
    @Test func freePlanIsMetered() {
        #expect(UsagePolicy.cleanExportLimit(for: .free) == 5)
        #expect(UsagePolicy.aiScriptLimit(for: .free) == 5)
    }

    @Test func subscribersAreUnlimited() {
        #expect(UsagePolicy.cleanExportLimit(for: .subscriber) == nil)
        #expect(UsagePolicy.aiScriptLimit(for: .subscriber) == nil)
    }

    @Test func lifetimeHasUnlimitedExportsAndMonthlyAI() {
        #expect(UsagePolicy.cleanExportLimit(for: .lifetime) == nil)
        #expect(UsagePolicy.aiScriptLimit(for: .lifetime) == 30)
    }

    @Test func monthKeyIsYearAndPaddedMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let date = calendar.date(from: DateComponents(year: 2026, month: 9, day: 26))!
        #expect(UsagePolicy.monthKey(for: date, calendar: calendar) == "2026-09")
    }
}
