//
//  UniverseSnapshotTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// "Your universe": the shared videos counted by platform and by topic.
@Suite("UniverseSnapshot")
struct UniverseSnapshotTests {
    private func take(_ script: Script, platform: Platform, number: Int, at date: Date = TestData.now) -> Take {
        var take = TestData.take(scriptID: script.id, number: number, recordedAt: date)
        take.platform = platform
        return take
    }

    @Test func videosAreCountedByPlatformAndByTopic() {
        var food = TestData.script(title: "Dinners")
        food.topic = OnboardingTopic.niche(.food).id
        var tech = TestData.script(title: "Gadgets")
        tech.topic = OnboardingTopic.niche(.tech).id
        let takes = [take(food, platform: .tiktok, number: 1), take(food, platform: .tiktok, number: 2), take(tech, platform: .reels, number: 1)]
        let snapshot = UniverseSnapshot(
            sharedIDs: Set(takes.map(\.id)), takes: takes, scripts: [food, tech],
            topics: [.niche(.food), .niche(.tech)], firstShare: TestData.now
        )
        #expect(snapshot.total == 3)
        #expect(snapshot.platforms.map(\.platform) == [.tiktok, .reels])
        #expect(snapshot.count(for: .tiktok) == 2 && snapshot.count(for: .shorts) == 0)
        #expect(snapshot.topics.map(\.count) == [2, 1])
    }

    @Test func onlySharedVideosCount() {
        let script = TestData.script()
        let shared = take(script, platform: .tiktok, number: 1)
        let other = take(script, platform: .tiktok, number: 2)
        let snapshot = UniverseSnapshot(sharedIDs: [shared.id], takes: [shared, other], scripts: [script], topics: [], firstShare: nil)
        #expect(snapshot.total == 1 && snapshot.newest?.id == shared.id)
    }

    @Test func aDeletedVideoStillCountsButDrawsNoRoute() {
        let snapshot = UniverseSnapshot(sharedIDs: [UUID()], takes: [], scripts: [], topics: [], firstShare: nil)
        #expect(snapshot.total == 1 && snapshot.platforms.isEmpty && snapshot.newest == nil)
    }

    @Test func theYearCountsWhatWasMadeThisYear() {
        let script = TestData.script()
        let calendar = Calendar(identifier: .gregorian)
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let old = now.addingTimeInterval(-400 * 86_400)
        let takes = [take(script, platform: .tiktok, number: 1, at: now), take(script, platform: .tiktok, number: 2, at: old)]
        let snapshot = UniverseSnapshot(
            sharedIDs: Set(takes.map(\.id)), takes: takes, scripts: [script], topics: [], firstShare: nil, now: now, calendar: calendar
        )
        #expect(snapshot.sharedThisYear == 1)
    }
}
