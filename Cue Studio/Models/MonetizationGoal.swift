//
//  MonetizationGoal.swift
//  Cue Studio
//

import Foundation

/// Minimum-length rule a platform applies before a video earns money.
nonisolated enum MonetizationGoal: String, Codable, Sendable {
    case creatorRewards
    case midRollAds

    /// Completes "12s to …".
    var targetLabel: String {
        switch self {
        case .creatorRewards: String(localized: "monetize")
        case .midRollAds: String(localized: "mid-roll ads")
        }
    }

    /// Label under the minimum marker of the length meter.
    var meterLabel: String {
        switch self {
        case .creatorRewards: String(localized: "monetizes")
        case .midRollAds: String(localized: "mid-rolls")
        }
    }

    /// Why stopping early matters, shown when the creator tries to stop short.
    var stopWarning: String {
        switch self {
        case .creatorRewards:
            String(localized: "TikTok pays Creator Rewards over one minute.")
        case .midRollAds:
            String(localized: "YouTube only allows mid-roll ads on videos 8 minutes or longer.")
        }
    }
}
