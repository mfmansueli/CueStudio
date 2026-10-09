//
//  LocalDateTime.swift
//  Cue Studio
//

import Foundation

/// A time on the clock of wherever the creator is ("tomorrow at 10:00"), not an instant: a reminder set for 10:00 rings at 10:00 in the
/// time zone the iPhone is in when the day comes. The rules for the clock's odd days (`NOTIFICATIONS.md` §5):
/// - a time that doesn't exist (the hour skipped when daylight saving starts) rings at the first minute after the gap;
/// - a time that happens twice (the hour repeated when it ends) rings the first time.
nonisolated struct LocalDateTime: Codable, Hashable, Comparable, Sendable {
    var year: Int
    var month: Int
    var day: Int
    var hour: Int
    var minute: Int

    init(year: Int, month: Int, day: Int, hour: Int, minute: Int) {
        self.year = year
        self.month = month
        self.day = day
        self.hour = hour
        self.minute = minute
    }

    /// The clock reading of `date` in `calendar`'s time zone.
    init(_ date: Date, calendar: Calendar) {
        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        self.init(year: parts.year ?? 2000, month: parts.month ?? 1, day: parts.day ?? 1, hour: parts.hour ?? 0, minute: parts.minute ?? 0)
    }

    var components: DateComponents {
        DateComponents(year: year, month: month, day: day, hour: hour, minute: minute)
    }

    /// The instant this reading names in `calendar`'s time zone today: a skipped time moves past the gap, a repeated one is the first.
    func date(in calendar: Calendar) -> Date? {
        var dayStart = DateComponents(year: year, month: month, day: day)
        dayStart.hour = 0
        guard let midnight = calendar.date(from: dayStart) else { return nil }
        let wanted = DateComponents(hour: hour, minute: minute)
        if let exact = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: midnight, matchingPolicy: .nextTime,
                                     repeatedTimePolicy: .first, direction: .forward) {
            return exact
        }
        return calendar.date(byAdding: wanted, to: midnight)
    }

    /// The reading `date(in:)` actually lands on, for the system's trigger (it would otherwise guess on its own across a gap).
    func resolved(in calendar: Calendar) -> LocalDateTime? {
        date(in: calendar).map { LocalDateTime($0, calendar: calendar) }
    }

    static func < (lhs: LocalDateTime, rhs: LocalDateTime) -> Bool {
        (lhs.year, lhs.month, lhs.day, lhs.hour, lhs.minute) < (rhs.year, rhs.month, rhs.day, rhs.hour, rhs.minute)
    }
}
