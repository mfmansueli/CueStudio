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
    @Test func freePlanStartsWithFiveCleanExports() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let quota = UsageQuotaService(defaults: store.defaults)
        #expect(quota.cleanExportsLeft(for: .free) == 5)
        #expect(quota.canExportClean(tier: .free))
    }

    @Test func cleanExportsCountDownAndPersist() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let quota = UsageQuotaService(defaults: store.defaults)
        for _ in 0..<5 { quota.recordCleanExport(tier: .free) }
        #expect(quota.cleanExportsLeft(for: .free) == 0)
        #expect(!quota.canExportClean(tier: .free))
        let reloaded = UsageQuotaService(defaults: store.defaults)
        #expect(reloaded.cleanExportsLeft(for: .free) == 0)
    }

    @Test func proExportsAreNotCounted() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let quota = UsageQuotaService(defaults: store.defaults)
        quota.recordCleanExport(tier: .subscriber)
        quota.recordCleanExport(tier: .lifetime)
        #expect(quota.cleanExportsUsed == 0)
        #expect(quota.cleanExportsLeft(for: .subscriber) == nil)
        #expect(quota.canExportClean(tier: .lifetime))
    }

    @Test func legacyMonthlyAICountersAreRemoved() {
        let store = TestDefaults()
        defer { store.tearDown() }
        store.defaults.set(3, forKey: DefaultsKey.legacyAIScriptsUsedPrefix + "2026-09")
        _ = UsageQuotaService(defaults: store.defaults)
        #expect(store.defaults.object(forKey: DefaultsKey.legacyAIScriptsUsedPrefix + "2026-09") == nil)
    }
}
