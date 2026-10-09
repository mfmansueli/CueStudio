//
//  PlanningContext.swift
//  Cue Studio
//

import Foundation

/// What the planner needs besides the candidates: the clock, the creator's limits, and what was already sent or set.
nonisolated struct PlanningContext: Sendable {
    var now: Date
    var calendar: Calendar
    var policy = NotificationPolicy.standard
    var quietHours = QuietHours.standard
    var pausedUntil: Date?
    /// Automatic notifications whose time has passed (counted as sent), newest last.
    var sent: [AutomaticRecord] = []
    /// Every time a tool was put in front of the creator (notification or in the app).
    var exposures: [FeatureExposure] = []
    /// The reminders and routine times the creator set, in the past 12 hours and ahead (automatic ones keep 12 hours away).
    var userTimes: [Date] = []
    /// Days a My Cue Voice tip was shown: no tool or idea on those days.
    var tipDays: [Date] = []
    /// The first return attempt: from then on nothing else automatic is sent.
    var returnStart: Date?
}
