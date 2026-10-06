//
//  UniverseYears.swift
//  Cue Studio
//

import Foundation

/// The years of "Your universe" (9.2): the live one is the current calendar year; the years before it are sealed at Dec 31, 23:59 local time.
nonisolated enum UniverseYears {
    /// How many years the selector shows.
    static let selectorLimit = 3

    static func current(now: Date = .now, calendar: Calendar = .current) -> Int { calendar.component(.year, from: now) }

    /// The years in the selector, oldest first: the current one and the ones before it that have videos, the latest `selectorLimit`.
    static func selector(videos: [UniverseVideo], now: Date = .now, calendar: Calendar = .current) -> [Int] {
        let live = current(now: now, calendar: calendar)
        let years = Set(videos.map { calendar.component(.year, from: $0.date) }).union([live]).filter { $0 <= live }
        return Array(years.sorted().suffix(selectorLimit))
    }

    static func isSealed(_ year: Int, now: Date = .now, calendar: Calendar = .current) -> Bool { year < current(now: now, calendar: calendar) }

    /// The year the review row and the yellow button talk about: the selected one, or the latest year that has videos when the selected one has none.
    static func reviewYear(selected: Int, videos: [UniverseVideo], calendar: Calendar = .current) -> Int {
        if videos.contains(where: { $0.isIn(year: selected, calendar: calendar) }) { return selected }
        return videos.map { calendar.component(.year, from: $0.date) }.filter { $0 < selected }.max() ?? selected
    }

    /// The story of the live year opens on Dec 1; before that it is a preview.
    static func storyIsReady(year: Int, now: Date = .now, calendar: Calendar = .current) -> Bool {
        isSealed(year, now: now, calendar: calendar) || (current(now: now, calendar: calendar) == year && calendar.component(.month, from: now) == 12)
    }
}
