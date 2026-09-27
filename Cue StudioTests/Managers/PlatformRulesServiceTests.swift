//
//  PlatformRulesServiceTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

@MainActor
@Suite("PlatformRulesService")
struct PlatformRulesServiceTests {
    private let remote = URL(string: "https://example.com/PlatformRules.json")!

    private func rules(revision: Int, tikTokMinimum: Double = 60) -> PlatformRules {
        var rules = TestData.rules
        rules.revision = revision
        rules.platforms["tiktok"]?.monetization?.minimum = tikTokMinimum
        return rules
    }

    private func temporaryCache() -> URL {
        URL.temporaryDirectory.appending(path: "rules-\(UUID().uuidString).json")
    }

    @Test func newerRemoteRulesReplaceTheBundledOnesAndAreCached() async throws {
        let cache = temporaryCache()
        defer { try? FileManager.default.removeItem(at: cache) }
        let newer = try JSONEncoder().encode(rules(revision: 2, tikTokMinimum: 90))
        let service = PlatformRulesService(bundled: rules(revision: 1), cacheURL: cache, remoteURL: remote, fetcher: FakeRulesFetcher(result: .success(newer)))

        await service.refresh()

        #expect(service.rules.revision == 2)
        #expect(service.preset(for: .tiktok, monetizationGoals: true).minimum == 90)
        let relaunched = PlatformRulesService(bundled: rules(revision: 1), cacheURL: cache, remoteURL: nil)
        #expect(relaunched.rules.revision == 2)
    }

    @Test func olderRemoteRulesAreIgnored() async throws {
        let older = try JSONEncoder().encode(rules(revision: 1, tikTokMinimum: 90))
        let service = PlatformRulesService(bundled: rules(revision: 3), cacheURL: nil, remoteURL: remote, fetcher: FakeRulesFetcher(result: .success(older)))
        await service.refresh()
        #expect(service.rules.revision == 3)
        #expect(service.preset(for: .tiktok, monetizationGoals: true).minimum == 60)
    }

    @Test func incompleteRemoteRulesAreIgnored() async throws {
        var partial = rules(revision: 5)
        partial.platforms["linkedin"] = nil
        let service = PlatformRulesService(bundled: rules(revision: 1), cacheURL: nil, remoteURL: remote, fetcher: FakeRulesFetcher(result: .success(try JSONEncoder().encode(partial))))
        await service.refresh()
        #expect(service.rules.revision == 1)
    }

    @Test func networkFailureKeepsTheCurrentRules() async {
        let fetcher = FakeRulesFetcher(result: .failure(URLError(.notConnectedToInternet)))
        let service = PlatformRulesService(bundled: rules(revision: 1), cacheURL: nil, remoteURL: remote, fetcher: fetcher)
        await service.refresh()
        #expect(fetcher.requestedURL == remote)
        #expect(service.rules.revision == 1)
    }

    @Test func withoutARemoteURLNothingIsFetched() async {
        let fetcher = FakeRulesFetcher(result: .failure(URLError(.badURL)))
        let service = PlatformRulesService(bundled: rules(revision: 1), cacheURL: nil, remoteURL: nil, fetcher: fetcher)
        await service.refresh()
        #expect(fetcher.requestedURL == nil)
    }

    @Test func staleCacheLosesToANewerBundle() throws {
        let cache = temporaryCache()
        defer { try? FileManager.default.removeItem(at: cache) }
        try JSONEncoder().encode(rules(revision: 2)).write(to: cache)
        let service = PlatformRulesService(bundled: rules(revision: 4), cacheURL: cache, remoteURL: nil)
        #expect(service.rules.revision == 4)
    }
}
