//
//  ReminderFeedback.swift
//  Cue Studio
//

import UIKit

/// What the creator is told after setting a reminder, the same from every place that sets one. "Reminder set" only when the system accepted
/// it; with notifications off it says the reminder is kept in Cue and offers Settings (the creator's tap, never Cue's).
enum ReminderFeedback {
    static func show(_ result: ReminderResult, toast: ToastService) {
        switch result {
        case .scheduled(let date):
            toast.show(String(localized: "Reminder set · \(when(date))"))
        case .savedNotificationsOff:
            toast.show(
                String(localized: "Saved in Cue · notifications are off"),
                action: ToastAction(title: String(localized: "Settings")) {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }
            )
        case .savedWaiting:
            toast.show(String(localized: "Saved · Cue schedules it closer to the time"))
        case .past:
            toast.show(String(localized: "Pick a time in the future"))
        case .failed:
            toast.show(String(localized: "Couldn’t set the reminder · Try again"))
        }
    }

    /// "Today 8:00 PM", "Tomorrow 10:00 AM", "Oct 12, 6:00 PM": in the interface language, on the iPhone's clock.
    static func when(_ date: Date, now: Date = .now, calendar: Calendar = .current) -> String {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(.interface))
        if calendar.isDate(date, inSameDayAs: now) { return String(localized: "Today \(time)") }
        if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(date, inSameDayAs: tomorrow) {
            return String(localized: "Tomorrow \(time)")
        }
        return date.formatted(Date.FormatStyle(date: .abbreviated, time: .shortened).locale(.interface))
    }
}
