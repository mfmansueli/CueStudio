//
//  UsagePolicy.swift
//  Cue Studio
//

import Foundation

/// What the free plan limits: only exporting videos (saving to Photos or sharing). Every feature,
/// Apple Intelligence included (on the device or Private Cloud Compute, at no cost to anyone), stays
/// open to everyone; recording, editing and writing never stop.
nonisolated enum UsagePolicy {
    static let freeExports = 5

    /// Nil means unlimited.
    static func exportLimit(for tier: MembershipTier) -> Int? {
        tier == .free ? freeExports : nil
    }
}
