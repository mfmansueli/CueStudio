//
//  NotificationPolicy.swift
//  Cue Studio
//

import Foundation

/// Every limit of the notifications in one place (`NOTIFICATIONS.md` §6). A value, so tests and a future tuning change one number, and
/// the planner reads nothing else.
nonisolated struct NotificationPolicy: Hashable, Sendable {
    // MARK: Frequency (automatic notifications only: reminders and the routine are the creator's)
    /// At most one automatic notification in any 24 hours.
    var dailyCap = 1
    var dailyWindow: TimeInterval = 24 * 3600
    /// At most two automatic notifications in any 7 days, all automatic categories together.
    var weeklyCap = 2
    var weeklyWindow: TimeInterval = 7 * 24 * 3600
    /// At most one tool or idea in any 7 days.
    var discoveryWeeklyCap = 1
    /// The same tool at most twice in 90 days, at least 30 days apart; never again once it is used for real.
    var featureCap = 2
    var featureWindow: TimeInterval = 90 * 24 * 3600
    var featureCooldown: TimeInterval = 30 * 24 * 3600
    /// No automatic notification within 12 hours of a reminder or the routine the creator set.
    var userTimeExclusion: TimeInterval = 12 * 3600

    // MARK: Timing
    /// A draft with words in it, untouched this long.
    var unfinishedScriptDelay: TimeInterval = 72 * 3600
    /// A finished script with no take, or a first script.
    var readyToRecordDelay: TimeInterval = 48 * 3600
    /// A take with work left.
    var recordingToFinishDelay: TimeInterval = 48 * 3600
    /// A queue with networks waiting.
    var sharingDelay: TimeInterval = 24 * 3600
    /// A Logbook note still waiting.
    var savedIdeaAge: TimeInterval = 7 * 24 * 3600
    /// The two attempts after a break, counted from the last activity.
    var returnAttempts: [TimeInterval] = [7 * 24 * 3600, 21 * 24 * 3600]
    /// A tool or an idea waits this long after the last activity (never while the creator is working).
    var discoveryDelay: TimeInterval = 24 * 3600
    /// Nothing automatic sooner than this after planning.
    var minimumLead: TimeInterval = 15 * 60
    /// How far ahead automatic notifications are planned (the second return attempt is 21 days out).
    var horizon: TimeInterval = 23 * 24 * 3600
    /// A draft needs this many words to be "a real draft".
    var meaningfulWords = 8

    // MARK: Capacity (iOS keeps 64 pending requests per app; Cue stays well under)
    var maxPending = 32
    /// The routine: one repeating request per weekday.
    var routineCapacity = 7
    /// Automatic notifications planned at once.
    var automaticCapacity = 4
    /// What is left goes to the nearest reminders; later ones wait in Cue and are scheduled as places free up.
    var reminderCapacity: Int { maxPending - routineCapacity - automaticCapacity }

    static let standard = NotificationPolicy()
}
