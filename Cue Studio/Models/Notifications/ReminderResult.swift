//
//  ReminderResult.swift
//  Cue Studio
//

import Foundation

/// What happened to a reminder the creator set. "Set" is only said when the system accepted it.
nonisolated enum ReminderResult: Hashable, Sendable {
    /// The system will deliver it at that moment.
    case scheduled(Date)
    /// Kept in Cue but not handed to the system: notifications are off for Cue in iOS Settings, or "My reminders" is off.
    case savedNotificationsOff
    /// Kept in Cue; the nearest reminders hold the places, and this one is scheduled when one frees up.
    case savedWaiting
    /// The time is in the past.
    case past
    /// The system refused it; nothing was kept.
    case failed
}
