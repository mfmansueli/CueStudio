//
//  LogbookDays.swift
//  Cue Studio
//

import Foundation

/// The Logbook's ideas by the day they were caught, newest first: "TODAY", "YESTERDAY", the weekday within the last week, then the date (with
/// the year when it isn't this one). Each idea says how it came in and when ("SPOKEN · 0:06 · 2 HR. AGO" today, "TYPED · 9:40 PM" on an
/// earlier day), in the calendar's time zone. Pure, so tested.
nonisolated enum LogbookDays {
    struct Day: Equatable, Identifiable {
        /// The day's first moment: two days never share it, though an old date's title can repeat a year later.
        let id: Date
        let title: String
        let entries: [LogbookEntry]
    }

    static func days(of entries: [LogbookEntry], now: Date = .now, calendar: Calendar = .current, locale: Locale = .interface) -> [Day] {
        let newestFirst = entries.sorted { $0.createdAt > $1.createdAt }
        var days: [Day] = []
        for entry in newestFirst {
            let start = calendar.startOfDay(for: entry.createdAt)
            if let last = days.last, last.id == start {
                days[days.count - 1] = Day(id: start, title: last.title, entries: last.entries + [entry])
            } else {
                days.append(Day(id: start, title: title(for: entry.createdAt, now: now, calendar: calendar, locale: locale), entries: [entry]))
            }
        }
        return days
    }

    static func title(for date: Date, now: Date, calendar: Calendar, locale: Locale) -> String {
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Today").uppercased(with: locale) }
        let today = calendar.startOfDay(for: now)
        let day = calendar.startOfDay(for: date)
        let daysAgo = calendar.dateComponents([.day], from: day, to: today).day ?? 0
        if daysAgo == 1 { return String(localized: "Yesterday").uppercased(with: locale) }
        var style: Date.FormatStyle = if daysAgo < 7 {
            .dateTime.weekday(.wide).locale(locale)
        } else if calendar.component(.year, from: date) == calendar.component(.year, from: now) {
            .dateTime.month(.abbreviated).day().locale(locale)
        } else {
            .dateTime.month(.abbreviated).day().year().locale(locale)
        }
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style).uppercased(with: locale)
    }

    /// "SPOKEN · 0:06 · 2 HR. AGO" or "TYPED · NOW" today; "TYPED · 9:40 PM" on an earlier day.
    static func meta(for entry: LogbookEntry, now: Date = .now, calendar: Calendar = .current, locale: Locale = .interface) -> String {
        var time = Date.FormatStyle.dateTime.hour().minute().locale(locale)
        time.calendar = calendar
        time.timeZone = calendar.timeZone
        let when = calendar.isDate(entry.createdAt, inSameDayAs: now)
            ? entry.createdAt.formatted(.relative(presentation: .named).locale(locale))
            : entry.createdAt.formatted(time)
        let line = if let seconds = entry.spokenSeconds {
            String(localized: "Spoken · \(DurationText.clock(Double(seconds))) · \(when)")
        } else {
            String(localized: "Typed · \(when)")
        }
        return line.uppercased(with: locale)
    }
}
