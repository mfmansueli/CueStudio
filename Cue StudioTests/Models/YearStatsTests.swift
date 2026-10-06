//
//  YearStatsTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The numbers behind the story of a year.
@Suite("YearStats")
struct YearStatsTests {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.firstWeekday = 2
        return calendar
    }

    private func video(_ month: Int, _ day: Int = 10, year: Int = 2026, platform: Platform? = .tiktok, topic: OnboardingTopic? = nil) -> UniverseVideo {
        UniverseVideo(date: calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12))!, platform: platform, topic: topic?.id)
    }

    @Test func totalMainPlanetAndBestMonth() {
        let videos = [video(3), video(10), video(10), video(10, platform: .reels), video(12), video(1, year: 2025)]
        let stats = YearStats(videos: videos, year: 2026, topics: [], calendar: calendar)
        #expect(stats.total == 5)
        #expect(stats.mainPlatform == YearStats.PlatformCount(platform: .tiktok, count: 4))
        #expect(stats.bestMonth == 10)
        #expect(stats.months[9] == 3 && stats.months.reduce(0, +) == 5)
    }

    @Test func aTieInMonthsGoesToTheEarlierOne() {
        let stats = YearStats(videos: [video(4), video(4), video(9), video(9)], year: 2026, topics: [], calendar: calendar)
        #expect(stats.bestMonth == 4)
    }

    @Test func theStreakCountsWeeksInARowWithAVideo() {
        // Mondays 5, 12, 19 Jan 2026 are three weeks in a row; then a gap; then 9 Feb and 16 Feb.
        let videos = [video(1, 5), video(1, 14), video(1, 19), video(2, 9), video(2, 16)]
        #expect(YearStats(videos: videos, year: 2026, topics: [], calendar: calendar).longestStreakWeeks == 3)
    }

    @Test func twoVideosInTheSameWeekAreOneWeek() {
        #expect(YearStats(videos: [video(5, 4), video(5, 6)], year: 2026, topics: [], calendar: calendar).longestStreakWeeks == 1)
    }

    @Test func theStrongestThemeIsTheOneWithMostVideos() {
        let food = OnboardingTopic.niche(.food)
        let tech = OnboardingTopic.niche(.tech)
        let videos = [video(1, topic: food), video(2, topic: tech), video(3, topic: tech)]
        let stats = YearStats(videos: videos, year: 2026, topics: [food, tech], calendar: calendar)
        #expect(stats.strongestTheme?.topic == tech && stats.strongestTheme?.count == 2 && stats.strongestTheme?.topicIndex == 1)
    }

    @Test func slidesWithoutDataAreLeftOut() {
        let noTheme = YearStats(videos: [video(1), video(2), video(3)], year: 2026, topics: [], calendar: calendar)
        #expect(noTheme.slides == [.total, .planet, .month, .streak])
        let noPlatformEither = YearStats(videos: [video(1, platform: nil)], year: 2026, topics: [], calendar: calendar)
        #expect(noPlatformEither.slides == [.total, .month, .streak])
        #expect(noPlatformEither.slides.count >= 2, "the story always has at least two slides")
        #expect(YearStats(videos: [], year: 2026, topics: [], calendar: calendar).slides.isEmpty)
    }
}
