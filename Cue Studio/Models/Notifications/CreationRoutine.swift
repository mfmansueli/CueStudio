//
//  CreationRoutine.swift
//  Cue Studio
//

import Foundation

/// The days and the clock time the creator chose to create ("Mon, Wed, Fri at 6:00 PM"). It repeats every week at that time wherever
/// the iPhone is, and opens the best next step when tapped (`NotificationDestination.nextAction`).
nonisolated struct CreationRoutine: Codable, Hashable, Sendable {
    /// `Calendar` weekdays: 1 is Sunday, 7 is Saturday.
    var weekdays: Set<Int>
    var hour: Int
    var minute: Int

    init(weekdays: Set<Int> = [2, 4, 6], hour: Int = 18, minute: Int = 0) {
        self.weekdays = weekdays.filter { (1...7).contains($0) }
        self.hour = min(max(hour, 0), 23)
        self.minute = min(max(minute, 0), 59)
    }

    var minuteOfDay: Int { hour * 60 + minute }

    /// The next times it rings after `date`, up to `limit`, in `calendar`'s time zone (for the ±12 h around it that automatic ones avoid).
    func occurrences(after date: Date, until end: Date, calendar: Calendar) -> [Date] {
        var found: [Date] = []
        for weekday in weekdays.sorted() {
            let parts = DateComponents(hour: hour, minute: minute, weekday: weekday)
            var cursor = date
            while let next = calendar.nextDate(after: cursor, matching: parts, matchingPolicy: .nextTime), next <= end {
                found.append(next)
                cursor = next
            }
        }
        return found.sorted()
    }
}
