//
//  LocalNotificationRequest.swift
//  Cue Studio
//

import Foundation

/// A notification Cue asks the system to deliver later, as plain values (`SystemNotificationCenter` makes the system's request from it).
/// The system shows it at its time whether or not Cue runs; it doesn't tell Cue whether it was seen.
nonisolated struct LocalNotificationRequest: Hashable, Sendable {
    enum Trigger: Hashable, Sendable {
        /// Once, at that clock time wherever the iPhone is.
        case at(LocalDateTime)
        /// Every week on that weekday (1 is Sunday) at that clock time.
        case weekly(weekday: Int, hour: Int, minute: Int)
        /// In a second (a finished export while Cue isn't on screen).
        case soon
    }

    var identifier: String
    var content: NotificationContent
    var payload: NotificationPayload
    var trigger: Trigger

    /// Tools and news arrive quietly (no sound, no lit screen); what the creator set and their projects arrive as usual.
    var isPassive: Bool { payload.category == .discovery || payload.category == .whatsNew }
}
