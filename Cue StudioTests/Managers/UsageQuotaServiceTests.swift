//
//  UsageQuotaServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("UsageQuotaService")
struct UsageQuotaServiceTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    private func date(month: Int) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: 15))!
    }

    @Test func freePlanStartsWithFullQuota() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let quota = UsageQuotaService(defaults: store.defaults, calendar: calendar, now: { date(month: 9) })
        #expect(quota.cleanExportsLeft(for: .free) == 5)
        #expect(quota.aiScriptsLeft(for: .free) == 5)
    }

    @Test func cleanExportsCountDownAndPersist() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let quota = UsageQuotaService(defaults: store.defaults, calendar: calendar, now: { date(month: 9) })
        for _ in 0..<5 { quota.recordCleanExport(tier: .free) }
        #expect(quota.cleanExportsLeft(for: .free) == 0)
        #expect(!quota.canExportClean(tier: .free))
        let reloaded = UsageQuotaService(defaults: store.defaults, calendar: calendar, now: { date(month: 9) })
        #expect(reloaded.cleanExportsLeft(for: .free) == 0)
    }

    @Test func proUsageIsNotCounted() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let quota = UsageQuotaService(defaults: store.defaults, calendar: calendar, now: { date(month: 9) })
        quota.recordCleanExport(tier: .subscriber)
        quota.recordAIScript(tier: .subscriber)
        #expect(quota.cleanExportsUsed == 0)
        #expect(quota.aiScriptsUsedThisMonth == 0)
        #expect(quota.cleanExportsLeft(for: .subscriber) == nil)
        #expect(quota.canGenerateAIScript(tier: .subscriber))
    }

    @Test func aiQuotaResetsEachMonth() {
        let store = TestDefaults()
        defer { store.tearDown() }
        var month = 9
        let quota = UsageQuotaService(defaults: store.defaults, calendar: calendar, now: { date(month: month) })
        quota.recordAIScript(tier: .free)
        quota.recordAIScript(tier: .free)
        #expect(quota.aiScriptsLeft(for: .free) == 3)
        month = 10
        quota.refreshMonth()
        #expect(quota.aiScriptsLeft(for: .free) == 5)
    }

    @Test func lifetimeGetsThirtyAIScriptsAMonth() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let quota = UsageQuotaService(defaults: store.defaults, calendar: calendar, now: { date(month: 9) })
        quota.recordAIScript(tier: .lifetime)
        #expect(quota.aiScriptsLeft(for: .lifetime) == 29)
    }
}
