//
//  AttributionContext.swift
//  Cue Studio
//

import Foundation

/// The notification the creator opened last, for 24 hours (`lifetime`): a tool used or a step done in that time is counted as that
/// campaign's `feature_completed` / `next_action_completed`. After it expires nothing is attributed to it. Nothing about the creator's
/// content is in it.
nonisolated struct AttributionContext: Codable, Hashable, Sendable {
    static let lifetime: TimeInterval = 24 * 3600

    var campaignName: String
    var category: NotificationCategory
    var feature: FeatureID?
    var projectKey: String?
    /// The project's next step when it was opened (`NotificationCampaign.rawValue`): a different one later means the step was done.
    var projectStep: String?
    var openedAt: Date

    func isActive(at now: Date) -> Bool {
        now >= openedAt && now.timeIntervalSince(openedAt) < Self.lifetime
    }
}
