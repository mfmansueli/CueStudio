//
//  YearStats.swift
//  Cue Studio
//

import Foundation

/// What the story of a year tells (9.2 "Year in review"): the total, the main planet, the best month, the longest streak of weeks with a video, and the
/// strongest theme. A slide with nothing to say is left out.
nonisolated struct YearStats: Equatable, Sendable {
    enum Slide: Equatable, Sendable { case total, planet, month, streak, theme }

    struct PlatformCount: Equatable, Sendable {
        let platform: Platform
        let count: Int
    }

    struct ThemeCount: Equatable, Sendable {
        let topicIndex: Int
        let topic: OnboardingTopic
        let count: Int
    }

    /// A story needs at least this many videos in the year.
    static let videosToUnlock = 3

    let year: Int
    let total: Int
    let mainPlatform: PlatformCount?
    /// Videos in each month, January first.
    let months: [Int]
    /// 1…12; nil with no videos. A tie goes to the earlier month.
    let bestMonth: Int?
    let longestStreakWeeks: Int
    let strongestTheme: ThemeCount?

    init(videos: [UniverseVideo], year: Int, topics: [OnboardingTopic], calendar: Calendar = .current) {
        let shared = videos.filter { $0.isIn(year: year, calendar: calendar) }
        self.year = year
        total = shared.count
        var byPlatform: [Platform: Int] = [:]
        for video in shared { for platform in video.platforms { byPlatform[platform, default: 0] += 1 } }
        mainPlatform = byPlatform.max { ($0.value, $1.key.rawValue) < ($1.value, $0.key.rawValue) }.map { PlatformCount(platform: $0.key, count: $0.value) }
        var months = Array(repeating: 0, count: 12)
        for video in shared { months[calendar.component(.month, from: video.date) - 1] += 1 }
        self.months = months
        bestMonth = months.max().flatMap { best in best > 0 ? months.firstIndex(of: best).map { $0 + 1 } : nil }
        longestStreakWeeks = Self.longestStreak(of: shared.map(\.date), calendar: calendar)
        var themes: [ThemeCount] = []
        for (index, topic) in topics.enumerated() {
            themes.append(ThemeCount(topicIndex: index, topic: topic, count: shared.filter { $0.topic == topic.id }.count))
        }
        var strongest: ThemeCount?
        for theme in themes where theme.count > (strongest?.count ?? 0) { strongest = theme }
        strongestTheme = strongest
    }

    /// Weeks in a row with at least one video.
    static func longestStreak(of dates: [Date], calendar: Calendar) -> Int {
        let weeks = Set(dates.compactMap { calendar.dateInterval(of: .weekOfYear, for: $0)?.start }).sorted()
        var longest = 0
        var run = 0
        var previous: Date?
        for week in weeks {
            if let previous, calendar.date(byAdding: .weekOfYear, value: 1, to: previous) == week { run += 1 } else { run = 1 }
            longest = max(longest, run)
            previous = week
        }
        return longest
    }

    /// The story's slides, in order. Always at least two once the year has a video.
    var slides: [Slide] {
        guard total > 0 else { return [] }
        var slides: [Slide] = [.total]
        if mainPlatform != nil { slides.append(.planet) }
        if bestMonth != nil { slides.append(.month) }
        if longestStreakWeeks > 0 { slides.append(.streak) }
        if strongestTheme != nil { slides.append(.theme) }
        return slides
    }
}
