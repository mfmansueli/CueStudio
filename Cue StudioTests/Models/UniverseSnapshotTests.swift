//
//  UniverseSnapshotTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// One year of "Your universe": what was shared in it, by platform and by topic, and the dots on the map.
@Suite("UniverseSnapshot")
struct UniverseSnapshotTests {
    private let calendar = Calendar(identifier: .gregorian)

    private func date(_ year: Int, _ month: Int = 6, _ day: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!
    }

    private func video(_ year: Int, platform: Platform? = .tiktok, topic: OnboardingTopic? = nil, month: Int = 6) -> UniverseVideo {
        UniverseVideo(date: date(year, month), platform: platform, topic: topic?.id)
    }

    @Test func videosAreCountedByPlatformAndByTopic() {
        let videos = [
            video(2026, platform: .tiktok, topic: .niche(.food)), video(2026, platform: .tiktok, topic: .niche(.food)),
            video(2026, platform: .reels, topic: .niche(.tech)),
        ]
        let snapshot = UniverseSnapshot(videos: videos, year: 2026, topics: [.niche(.food), .niche(.tech)], calendar: calendar)
        #expect(snapshot.total == 3)
        #expect(snapshot.platforms.map(\.platform) == [.tiktok, .reels])
        #expect(snapshot.count(for: .tiktok) == 2 && snapshot.count(for: .shorts) == 0)
        #expect(snapshot.topics.map(\.count) == [2, 1])
    }

    @Test func onlyTheVideosOfThatYearCount() {
        let videos = [video(2026), video(2026), video(2025), video(2024)]
        #expect(UniverseSnapshot(videos: videos, year: 2026, topics: [], calendar: calendar).total == 2)
        #expect(UniverseSnapshot(videos: videos, year: 2025, topics: [], calendar: calendar).total == 1)
        #expect(UniverseSnapshot(videos: videos, year: 2027, topics: [], calendar: calendar).total == 0)
    }

    @Test func theFirstShareIsTheOldestEvenInAnotherYear() {
        let snapshot = UniverseSnapshot(videos: [video(2026), video(2024)], year: 2026, topics: [], calendar: calendar)
        #expect(snapshot.firstShare == date(2024))
    }

    @Test func theNewestIsTheLastOneOfTheYear() {
        let last = UniverseVideo(date: date(2026, 9), platform: .reels)
        let snapshot = UniverseSnapshot(videos: [video(2026, month: 3), last, video(2025, month: 12)], year: 2026, topics: [], calendar: calendar)
        #expect(snapshot.newest?.id == last.id)
    }

    @Test func aVideoWithoutPlatformStillCountsButDrawsNoRoute() {
        let snapshot = UniverseSnapshot(videos: [video(2026, platform: nil)], year: 2026, topics: [], calendar: calendar)
        #expect(snapshot.total == 1 && snapshot.platforms.isEmpty)
    }

    @Test func eachVideoOfATopicGetsItsOwnDotAndAtMostFortyAreDrawn() {
        let videos = (0..<50).map { _ in video(2026, topic: .niche(.food)) }
        let snapshot = UniverseSnapshot(videos: videos, year: 2026, topics: [.niche(.food)], calendar: calendar)
        #expect(snapshot.total == 50)
        #expect(snapshot.dots.count == UniverseSnapshot.dotLimit)
        #expect(snapshot.dots.map(\.slot) == Array(0..<UniverseSnapshot.dotLimit))
    }

    @Test func aVideoOfAnUnknownTopicHasNoDot() {
        let snapshot = UniverseSnapshot(videos: [video(2026, topic: .niche(.tech))], year: 2026, topics: [.niche(.food)], calendar: calendar)
        #expect(snapshot.total == 1 && snapshot.dots.isEmpty)
    }
}
