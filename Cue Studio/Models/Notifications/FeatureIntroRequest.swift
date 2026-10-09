//
//  FeatureIntroRequest.swift
//  Cue Studio
//

import Foundation

/// A tool to introduce in the app, on a real object of the creator's: a short sheet with one benefit, "Try it" and "Not now". "Try it"
/// opens the tool; nothing in it runs until the creator uses it there.
nonisolated struct FeatureIntroRequest: Identifiable, Hashable, Sendable {
    enum Source: Hashable, Sendable {
        /// The creator opened a discovery notification.
        case notification(campaign: String)
        /// Cue offered it at a quiet moment.
        case inApp
    }

    var feature: FeatureID
    var destination: NotificationDestination
    var projectKey: String
    var source: Source

    var id: String { "\(feature.rawValue).\(projectKey)" }

    var campaignName: String {
        switch source {
        case .notification(let campaign): campaign
        case .inApp: "inApp.\(feature.rawValue)"
        }
    }
}
