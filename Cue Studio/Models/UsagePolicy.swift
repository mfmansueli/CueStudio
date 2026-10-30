//
//  UsagePolicy.swift
//  Cue Studio
//

import Foundation

/// What the free plan limits: only exporting videos (saving to Photos or sharing), and, where Ultra AI is offered, its scripts (each one costs a
/// call to Google). Every other feature, Apple Intelligence included (on the device or Private Cloud Compute, at no cost to anyone), stays open
/// to everyone; recording, editing and writing never stop.
nonisolated enum UsagePolicy {
    /// Trying Cue is its free exports and Ultra AI scripts: Cue Pro has no free trial (owner, 30/10/2026).
    static let freeExports = 3
    /// Ultra AI scripts everyone gets to try it (owner, 30/10/2026).
    static let freeUltraScripts = 3
    /// Ultra AI scripts Cue Pro adds each month, from the day it starts.
    static let proUltraScriptsPerMonth = 30

    /// Nil means unlimited.
    static func exportLimit(for tier: MembershipTier) -> Int? {
        tier == .free ? freeExports : nil
    }
}
