//
//  Reminder.swift
//  Cue Studio
//

import Foundation

/// A reminder the creator set: what it is about, and the clock time it rings at wherever they are. Kept in Cue whether or not the
/// system lets it ring, so turning notifications off never loses one; `isScheduled` says only that the system accepted it.
nonisolated struct Reminder: Codable, Identifiable, Hashable, Sendable {
    var id = UUID()
    var subject: ReminderSubject
    var time: LocalDateTime
    var createdAt: Date
    /// The project's title when it was set, for the list in Settings (shown in a notification only with "Show titles in previews").
    var title: String
    /// The system accepted it (`UNUserNotificationCenter.add` succeeded). False while notifications are off, or while it waits for a
    /// free place (the nearest reminders go first, `NotificationPolicy.reminderCapacity`).
    var isScheduled = false

    /// Its request in the system: the same ID replaces it, so editing never makes a second one.
    var requestID: String { NotificationIdentifier.reminder(id) }

    func isDue(at now: Date, calendar: Calendar) -> Bool {
        guard let date = time.date(in: calendar) else { return true }
        return date <= now
    }
}
