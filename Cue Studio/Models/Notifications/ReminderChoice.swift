//
//  ReminderChoice.swift
//  Cue Studio
//

import Foundation

/// The times the reminder sheet offers: tonight at 8 PM (until 7:30 PM), tomorrow at 10 AM, or a date and time the creator picks.
nonisolated enum ReminderChoice: Hashable, Sendable {
    static let tonightHour = 20
    static let tomorrowHour = 10
    /// "Tonight" stops being offered this close to it.
    static let tonightCutoff: TimeInterval = 30 * 60

    case tonight
    case tomorrow
    case custom(Date)

    /// The clock time it means from `now`; nil when it doesn't exist any more (tonight, after 7:30 PM).
    func time(now: Date, calendar: Calendar) -> LocalDateTime? {
        switch self {
        case .tonight:
            guard let tonight = calendar.date(bySettingHour: Self.tonightHour, minute: 0, second: 0, of: now),
                  tonight.timeIntervalSince(now) >= Self.tonightCutoff else { return nil }
            return LocalDateTime(tonight, calendar: calendar)
        case .tomorrow:
            guard let next = calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now)),
                  let morning = calendar.date(bySettingHour: Self.tomorrowHour, minute: 0, second: 0, of: next) else { return nil }
            return LocalDateTime(morning, calendar: calendar)
        case .custom(let date):
            return LocalDateTime(date, calendar: calendar)
        }
    }

    /// The picked time is in the past (or the next minute): it can't be a reminder.
    static func isPast(_ time: LocalDateTime, now: Date, calendar: Calendar) -> Bool {
        guard let date = time.date(in: calendar) else { return true }
        return date.timeIntervalSince(now) < 60
    }
}
