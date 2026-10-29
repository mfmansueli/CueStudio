//
//  UsagePolicy.swift
//  Cue Studio
//

import Foundation

/// What the free plan limits: only exporting videos (saving to Photos or sharing), and, where Ultra AI is offered, its scripts (each one costs a
/// call to Google). Every other feature, Apple Intelligence included (on the device or Private Cloud Compute, at no cost to anyone), stays open
/// to everyone; recording, editing and writing never stop.
nonisolated enum UsagePolicy {
    static let freeExports = 5
    /// Ultra AI scripts everyone gets to try it, the Pro trial included (owner, 29/10/2026).
    static let freeUltraScripts = 5
    /// Ultra AI scripts Cue Pro adds each month, from the first paid month (the trial has the free ones only).
    static let proUltraScriptsPerMonth = 30

    /// Nil means unlimited.
    static func exportLimit(for tier: MembershipTier) -> Int? {
        tier == .free ? freeExports : nil
    }
}
