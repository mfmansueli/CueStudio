//
//  SuppressionReason.swift
//  Cue Studio
//

import Foundation

/// Why an eligible notification was not scheduled. Measured (`suppressed`, with the reason) so the rules can be tuned; never shown.
nonisolated enum SuppressionReason: String, Codable, CaseIterable, Sendable {
    case categoryOff
    case notAuthorized
    case paused
    case quietHours
    case dailyCap
    case weeklyCap
    case discoveryWeeklyCap
    case featureCap
    case featureCooldown
    case nearUserReminder
    case voiceTipSameDay
    case replacedByReturn
    case sameProject
    case capacity
    case beyondHorizon
    case notInterested
    case snoozed
    case adopted
    case unavailable
    case foregroundBusy
}
