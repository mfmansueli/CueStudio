//
//  MonetizationGoal.swift
//  Cue Studio
//

import Foundation

/// Minimum-length rule a platform applies before a video can earn money. Cue only knows the length: its words name the length goal, never a
/// promise of earnings (decision 8, 30/10/2026).
nonisolated enum MonetizationGoal: String, Codable, Sendable {
    case creatorRewards
    case midRollAds

    /// Completes "12s to …".
    var targetLabel: String {
        switch self {
        case .creatorRewards: String(localized: "the length goal")
        case .midRollAds: String(localized: "mid-roll ads")
        }
    }

    /// Label under the minimum marker of the length meter.
    var meterLabel: String {
        switch self {
        case .creatorRewards: String(localized: "Creator Rewards")
        case .midRollAds: String(localized: "mid-rolls")
        }
    }

    /// Why stopping early matters, shown when the creator tries to stop short.
    var stopWarning: String {
        switch self {
        case .creatorRewards:
            String(localized: "Creator Rewards only counts videos over one minute, and TikTok has other rules too.")
        case .midRollAds:
            String(localized: "YouTube only allows mid-roll ads on videos 8 minutes or longer.")
        }
    }
}
