//
//  AutomaticRecord.swift
//  Cue Studio
//

import Foundation

/// An automatic notification Cue handed to the system: what it was for and when it was due. The system never tells an app whether a
/// notification was shown or seen, so a record whose time has passed counts as **sent** for the caps (the careful reading: it may have
/// rung) and is never reported as delivered. One still in the future is a **reservation**: it holds its place in the caps until the next
/// plan replaces it.
nonisolated struct AutomaticRecord: Codable, Hashable, Sendable {
    enum Status: String, Codable, Sendable {
        case reserved
        case sent
    }

    var requestID: String
    var campaign: NotificationCampaign
    var feature: FeatureID?
    var projectKey: String
    var fireDate: Date
    var status: Status

    var isDiscovery: Bool { campaign.isDiscovery }
}
