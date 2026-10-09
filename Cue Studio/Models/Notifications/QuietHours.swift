//
//  QuietHours.swift
//  Cue Studio
//

import Foundation

/// The hours automatic notifications wait out (21:00 to 09:00 unless the creator changes them), on the clock of wherever the iPhone is.
/// A reminder or routine the creator set inside them still rings: they chose that time, and the screen says so.
nonisolated struct QuietHours: Codable, Hashable, Sendable {
    /// Minutes after midnight. Start after end means the quiet runs over midnight.
    var startMinute: Int
    var endMinute: Int

    static let standard = QuietHours(startMinute: 21 * 60, endMinute: 9 * 60)

    init(startMinute: Int, endMinute: Int) {
        self.startMinute = Self.clamped(startMinute)
        self.endMinute = Self.clamped(endMinute)
    }

    /// Start and end at the same minute: no quiet hours.
    var isEmpty: Bool { startMinute == endMinute }

    func contains(minuteOfDay minute: Int) -> Bool {
        guard !isEmpty else { return false }
        if startMinute < endMinute { return minute >= startMinute && minute < endMinute }
        return minute >= startMinute || minute < endMinute
    }

    func contains(_ date: Date, calendar: Calendar) -> Bool {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return contains(minuteOfDay: (parts.hour ?? 0) * 60 + (parts.minute ?? 0))
    }

    func contains(_ time: LocalDateTime) -> Bool { contains(minuteOfDay: time.hour * 60 + time.minute) }

    /// `date`, or the end of the quiet it falls in.
    func nextAllowed(after date: Date, calendar: Calendar) -> Date {
        guard contains(date, calendar: calendar) else { return date }
        let end = DateComponents(hour: endMinute / 60, minute: endMinute % 60)
        return calendar.nextDate(after: date, matching: end, matchingPolicy: .nextTime) ?? date
    }

    private static func clamped(_ minute: Int) -> Int { min(max(minute, 0), 24 * 60 - 1) }
}
