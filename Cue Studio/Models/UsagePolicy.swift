//
//  UsagePolicy.swift
//  Cue Studio
//

import Foundation

/// Free-plan limits. The teleprompter and Apple Intelligence (on the device or Private Cloud
/// Compute, at no cost to anyone) are unlimited; only clean exports are metered.
nonisolated enum UsagePolicy {
    static let freeCleanExports = 5

    /// Nil means unlimited.
    static func cleanExportLimit(for tier: MembershipTier) -> Int? {
        tier == .free ? freeCleanExports : nil
    }
}
