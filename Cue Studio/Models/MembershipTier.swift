//
//  MembershipTier.swift
//  Cue Studio
//

import Foundation

/// Every feature is open on both; the tier only decides whether exports are metered.
nonisolated enum MembershipTier: String, Codable, Sendable {
    case free
    /// Cue Pro, monthly or annual (a free trial counts).
    case subscriber

    var isPro: Bool { self == .subscriber }
}
