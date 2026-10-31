//
//  IdeaCalendar.swift
//  Cue Studio
//

import Foundation

/// The occasions near a day where the creator lives (their region, `Locale.current.region`): what ideas may be tied to in the weeks before. Kept
/// here, written by us, and worked out on the iPhone (Easter, the lunar and the Islamic calendars come from Foundation): nothing is asked of a
/// server, and nothing is said about trends. Each occasion is kept only where it is a day people plan videos around; Mother's and Father's Day
/// move with the country. A region we have no rule for gets the occasions kept everywhere; without a region (and in UI tests unless
/// `-uiTestOccasions`), none.
nonisolated enum IdeaCalendar {
    /// How a day is found in a year.
    enum Rule: Hashable, Sendable {
        case fixed(month: Int, day: Int)
        /// The `ordinal`th `weekday` (1 is Sunday) of `month`, `-1` the last one, then `plus` days.
        case weekday(ordinal: Int, weekday: Int, month: Int, plus: Int = 0)
        /// Days from Easter Sunday (Western).
        case easter(plus: Int)
        case chinese(month: Int, day: Int)
        case islamic(month: Int, day: Int)
        /// Known days ("2026-11-08"), for a calendar Foundation doesn't have.
        case listed([String])
    }

    /// Where an occasion is kept and on which day: `everywhere` in any region not in `except` (nil: only in `regions`), with a region's own day
    /// first.
    struct Schedule: Sendable {
        var everywhere: Rule?
        var regions: [String: Rule] = [:]
        var except: Set<String> = []
        var isApproximate = false
    }

    /// How many days ahead an occasion is suggested: a video planned, filmed and posted before the day.
    static let lead = 21
    /// An approximate one is suggested from a month before to a week after it starts.
    static let approximateLead = 30
    static let approximateAfter = 7

    /// The occasions from today to `lead` days ahead (an approximate one a little wider), the nearest first.
    static func occasions(near now: Date, region: String?, calendar: Calendar = .current) -> [IdeaOccasion] {
        let today = calendar.startOfDay(for: now)
        let year = calendar.component(.year, from: today)
        var found: [IdeaOccasion] = []
        for kind in IdeaOccasion.Kind.allCases {
            let schedule = Self.schedule(of: kind)
            for date in (year - 1...year + 1).flatMap({ days(of: kind, year: $0, region: region, calendar: calendar) }) {
                guard let distance = calendar.dateComponents([.day], from: today, to: date).day else { continue }
                let window = schedule.isApproximate ? -approximateAfter...approximateLead : 0...lead
                if window.contains(distance) { found.append(IdeaOccasion(kind: kind, date: date, isApproximate: schedule.isApproximate)) }
            }
        }
        return found.sorted { $0.date < $1.date }
    }

    /// The days of `kind` in `year` where the creator lives: none when it isn't kept there.
    static func days(of kind: IdeaOccasion.Kind, year: Int, region: String?, calendar: Calendar = .current) -> [Date] {
        guard let region else { return [] }
        let schedule = Self.schedule(of: kind)
        let rule = schedule.regions[region] ?? (schedule.except.contains(region) ? nil : schedule.everywhere)
        guard let rule else { return [] }
        return dates(of: rule, year: year, calendar: calendar)
    }

    // MARK: - Rules

    static func dates(of rule: Rule, year: Int, calendar: Calendar = .current) -> [Date] {
        switch rule {
        case .fixed(let month, let day):
            return [calendar.date(from: DateComponents(year: year, month: month, day: day))].compactMap { $0 }
        case .weekday(let ordinal, let weekday, let month, let plus):
            var parts = DateComponents(year: year, month: month, weekday: weekday, weekdayOrdinal: ordinal)
            parts.calendar = calendar
            guard let day = calendar.date(from: parts) else { return [] }
            return [calendar.date(byAdding: .day, value: plus, to: day)].compactMap { $0 }
        case .easter(let plus):
            guard let sunday = easter(year: year, calendar: calendar) else { return [] }
            return [calendar.date(byAdding: .day, value: plus, to: sunday)].compactMap { $0 }
        case .chinese(let month, let day):
            return search(year: year, calendar: calendar, in: Calendar(identifier: .chinese), month: month, day: day)
        case .islamic(let month, let day):
            return search(year: year, calendar: calendar, in: Calendar(identifier: .islamicUmmAlQura), month: month, day: day)
        case .listed(let days):
            return days.compactMap { text -> Date? in
                let parts = text.split(separator: "-").compactMap { Int($0) }
                guard parts.count == 3, parts[0] == year else { return nil }
                return calendar.date(from: DateComponents(year: parts[0], month: parts[1], day: parts[2]))
            }
        }
    }

    /// Western Easter Sunday (the anonymous Gregorian algorithm).
    static func easter(year: Int, calendar: Calendar = .current) -> Date? {
        // The names follow Meeus.
        let a = year % 19, b = year / 100, c = year % 100, d = b / 4, e = b % 4, f = (b + 8) / 25, g = (b - f + 1) / 3
        let h = (19 * a + b - d - g + 15) % 30, i = c / 4, k = c % 4, l = (32 + 2 * e + 2 * i - h - k) % 7, m = (a + 11 * h + 22 * l) / 451
        let month = (h + l - 7 * m + 114) / 31, day = (h + l - 7 * m + 114) % 31 + 1
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// The days of `year` that are `month`/`day` in `other` (a leap month never counts): a lunar or Islamic date falls on one or two of them.
    private static func search(year: Int, calendar: Calendar, in other: Calendar, month: Int, day: Int) -> [Date] {
        guard let start = calendar.date(from: DateComponents(year: year, month: 1, day: 1)),
              let range = calendar.range(of: .day, in: .year, for: start) else { return [] }
        return range.compactMap { offset -> Date? in
            guard let date = calendar.date(byAdding: .day, value: offset - 1, to: start) else { return nil }
            let parts = other.dateComponents([.month, .day], from: date)
            guard parts.month == month, parts.day == day, parts.isLeapMonth != true else { return nil }
            return date
        }
    }
}
