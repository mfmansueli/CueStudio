//
//  NotificationOutcome.swift
//  Cue Studio
//

import Foundation

/// What is measured about a campaign (`NotificationMetrics`). Kept apart on purpose: **scheduled** (the system accepted the request),
/// **opened** (the creator tapped it), **feature_started** (they chose "Try it" and the tool opened), **feature_completed** (they used it
/// for real) and **next_action_completed** (the project moved on). There is no "delivered" or "seen": iOS doesn't tell an app either.
nonisolated enum NotificationOutcome: String, Codable, CaseIterable, Sendable {
    case eligible
    case suppressed
    case scheduled
    case schedulingFailed = "scheduling_failed"
    case cancelled
    case opened
    case snoozed
    case optedOut = "opted_out"
    case featureStarted = "feature_started"
    case featureCompleted = "feature_completed"
    case nextActionCompleted = "next_action_completed"
}
