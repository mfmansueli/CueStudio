//
//  NotificationIdentifier.swift
//  Cue Studio
//

import Foundation

/// The system identifiers of Cue's requests. Deterministic, so scheduling again replaces instead of adding, and cancelling needs no lookup.
/// Every one starts with "cue." and says its kind, so the reconciliation knows which pending requests are its own to replace.
nonisolated enum NotificationIdentifier {
    static let prefix = "cue."
    static let automaticPrefix = "cue.auto."
    static let reminderPrefix = "cue.reminder."
    static let routinePrefix = "cue.routine."
    static let operationPrefix = "cue.done."

    static func reminder(_ id: UUID) -> String { reminderPrefix + id.uuidString }

    /// One per weekday of the routine (1 is Sunday, as `Calendar` counts).
    static func routine(weekday: Int) -> String { routinePrefix + String(weekday) }

    /// One per campaign and project: the next plan replaces it.
    static func automatic(_ campaign: NotificationCampaign, feature: FeatureID?, projectKey: String) -> String {
        automaticPrefix + [campaign.rawValue, feature?.rawValue ?? "-", projectKey].joined(separator: ".")
    }

    static func exportReady(takeID: UUID) -> String { operationPrefix + "export." + takeID.uuidString }

    static func isAutomatic(_ identifier: String) -> Bool { identifier.hasPrefix(automaticPrefix) }

    static func isRoutine(_ identifier: String) -> Bool { identifier.hasPrefix(routinePrefix) }

    static func isReminder(_ identifier: String) -> Bool { identifier.hasPrefix(reminderPrefix) }
}
