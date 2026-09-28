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
    @Test func freePlanStartsWithFiveExports() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let quota = UsageQuotaService(counter: FakeExportCountStore(), defaults: store.defaults)
        #expect(quota.exportsLeft(for: .free) == 5)
        #expect(quota.canExport(tier: .free))
    }

    @Test func exportsCountDownAndOutliveTheApp() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let counter = FakeExportCountStore()
        let quota = UsageQuotaService(counter: counter, defaults: store.defaults)
        for _ in 0..<5 { quota.recordExport(tier: .free) }
        #expect(quota.exportsLeft(for: .free) == 0)
        #expect(!quota.canExport(tier: .free))
        #expect(counter.count == 5)
        // A reinstall starts with empty UserDefaults, but the count is still there.
        let other = TestDefaults()
        defer { other.tearDown() }
        let reloaded = UsageQuotaService(counter: counter, defaults: other.defaults)
        #expect(reloaded.exportsLeft(for: .free) == 0)
    }

    @Test func subscriberExportsAreNotCounted() {
        let store = TestDefaults()
        defer { store.tearDown() }
        let quota = UsageQuotaService(counter: FakeExportCountStore(), defaults: store.defaults)
        quota.recordExport(tier: .subscriber)
        #expect(quota.exportsUsed == 0)
        #expect(quota.exportsLeft(for: .subscriber) == nil)
        #expect(quota.canExport(tier: .subscriber))
    }

    @Test func theOldCountMovesToTheKeychain() {
        let store = TestDefaults()
        defer { store.tearDown() }
        store.defaults.set(3, forKey: DefaultsKey.legacyCleanExportsUsed)
        let counter = FakeExportCountStore(count: 1)
        let quota = UsageQuotaService(counter: counter, defaults: store.defaults)
        #expect(quota.exportsUsed == 3)
        #expect(counter.count == 3)
        #expect(store.defaults.object(forKey: DefaultsKey.legacyCleanExportsUsed) == nil)
    }

    @Test func legacyMonthlyAICountersAreRemoved() {
        let store = TestDefaults()
        defer { store.tearDown() }
        store.defaults.set(3, forKey: DefaultsKey.legacyAIScriptsUsedPrefix + "2026-09")
        _ = UsageQuotaService(counter: FakeExportCountStore(), defaults: store.defaults)
        #expect(store.defaults.object(forKey: DefaultsKey.legacyAIScriptsUsedPrefix + "2026-09") == nil)
    }
}
