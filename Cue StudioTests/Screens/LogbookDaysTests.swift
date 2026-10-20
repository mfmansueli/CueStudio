//
//  LogbookDaysTests.swift
//  Cue StudioTests
//

import Foundation
import Testing
@testable import Cue_Studio

/// The Logbook's ideas by day, newest first, and the line each says about how and when it came in.
@Suite("Logbook days")
struct LogbookDaysTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
    private let locale = Locale(identifier: "en_US")
    /// Tuesday 20 October 2026, 18:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_792_519_200)

    private func entry(_ text: String, hoursAgo: Double, spoken: Int? = nil) -> LogbookEntry {
        LogbookEntry(text: text, spokenSeconds: spoken, createdAt: now.addingTimeInterval(-hoursAgo * 3600))
    }

    @Test func ideasAreGroupedTodayYesterdayThenTheWeekdayThenTheDateNewestFirst() {
        let entries = [
            entry("Old", hoursAgo: 24 * 12), entry("This morning", hoursAgo: 5), entry("Last night", hoursAgo: 22),
            entry("Saturday", hoursAgo: 24 * 3), entry("Just now", hoursAgo: 0.1),
        ]
        let days = LogbookDays.days(of: entries, now: now, calendar: calendar, locale: locale)
        #expect(days.map(\.title) == ["TODAY", "YESTERDAY", "SATURDAY", "OCT 8"])
        #expect(days.first?.entries.map(\.text) == ["Just now", "This morning"])
    }

    @Test func eachIdeaSaysHowItCameInAndWhen() {
        let spoken = LogbookDays.meta(for: entry("Coffee", hoursAgo: 2, spoken: 6), now: now, calendar: calendar, locale: locale)
        #expect(spoken.hasPrefix("SPOKEN · 0:06 · "), "\(spoken)")
        let typedEarlier = LogbookDays.meta(for: entry("Mornings", hoursAgo: 22), now: now, calendar: calendar, locale: locale)
        #expect(typedEarlier.hasPrefix("TYPED · ") && typedEarlier.contains("PM"), "\(typedEarlier)")
    }

    /// A date from another year says its year, and stays its own day even where the dates read alike.
    @Test func anOldDateFromAnotherYearSaysTheYear() {
        let entries = [entry("This year", hoursAgo: 24 * 12), entry("Last year", hoursAgo: 24 * (12 + 365))]
        let days = LogbookDays.days(of: entries, now: now, calendar: calendar, locale: locale)
        #expect(days.map(\.title) == ["OCT 8", "OCT 8, 2025"])
        #expect(Set(days.map(\.id)).count == 2)
    }

    @Test func anEmptyLogbookHasNoDays() {
        #expect(LogbookDays.days(of: [], now: now, calendar: calendar, locale: locale).isEmpty)
    }
}
