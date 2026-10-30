//
//  UltraAllowance.swift
//  Cue Studio
//

import Foundation

/// How many Ultra AI scripts the creator may still write, as the owner set it (29/10/2026, 30/10/2026): the free ones for everyone, and with
/// Cue Pro `UsagePolicy.proUltraScriptsPerMonth` more each month. The free ones are spent first. Pure: the
/// counts come from `UltraAllowanceService`, the membership from `StoreManager`.
nonisolated struct UltraAllowance: Equatable, Sendable {
    enum Membership: Equatable, Sendable {
        case free
        /// Cue Pro.
        case paid

        init(tier: MembershipTier) {
            self = tier.isPro ? .paid : .free
        }
    }

    var membership: Membership
    var freeUsed: Int
    /// Scripts written this month out of Pro's monthly ones.
    var monthUsed: Int

    var freeLeft: Int { max(0, UsagePolicy.freeUltraScripts - freeUsed) }
    var monthLeft: Int { membership == .paid ? max(0, UsagePolicy.proUltraScriptsPerMonth - monthUsed) : 0 }
    var left: Int { freeLeft + monthLeft }

    /// After one more script: out of the free ones first.
    func spending() -> UltraAllowance {
        var next = self
        if freeLeft > 0 {
            next.freeUsed += 1
        } else if monthLeft > 0 {
            next.monthUsed += 1
        }
        return next
    }
}
