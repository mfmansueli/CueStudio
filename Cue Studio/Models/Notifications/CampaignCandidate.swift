//
//  CampaignCandidate.swift
//  Cue Studio
//

import Foundation

/// An automatic notification with a real reason to exist now or later: its campaign, the project it is about, the earliest moment it
/// makes sense, and where it goes. The planner decides whether and when it is scheduled (`NotificationPlanner`).
nonisolated struct CampaignCandidate: Hashable, Sendable {
    var campaign: NotificationCampaign
    var feature: FeatureID?
    var projectKey: String
    var earliest: Date
    var destination: NotificationDestination
    var subject: NotificationSubject

    var requestID: String { NotificationIdentifier.automatic(campaign, feature: feature, projectKey: projectKey) }

    var payload: NotificationPayload {
        NotificationPayload(campaign: campaign, feature: feature, destination: destination, projectKey: projectKey)
    }
}
