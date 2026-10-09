//
//  NotificationTelemetryEvent.swift
//  Cue Studio
//

import Foundation

/// One measured moment of a campaign: its name, category and outcome (and why, when it was held back). Sent only with "Help improve Cue"
/// on; never a title, a script, writing, audio or an account.
nonisolated struct NotificationTelemetryEvent: Hashable, Sendable {
    var campaign: String
    var category: NotificationCategory
    var outcome: NotificationOutcome
    var reason: SuppressionReason?

    /// The local counter it adds to ("projects.readyToRecord.suppressed.dailyCap").
    var counterKey: String {
        [campaign, outcome.rawValue, reason?.rawValue].compactMap(\.self).joined(separator: ".")
    }

    var parameters: [String: String] {
        var parameters = ["campaign": campaign, "category": category.rawValue, "outcome": outcome.rawValue]
        if let reason { parameters["reason"] = reason.rawValue }
        return parameters
    }
}
