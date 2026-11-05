//
//  ReferralRewards.swift
//  Cue Studio
//

import Foundation

/// What the creator's invites earned, friend by friend (owner, 05/11/2026): on the free plan 3 more exports for each friend who exported their
/// first video; on Cue Pro, where Ultra AI is offered, 5 more Ultra AI scripts (Pro's exports are unlimited already). Each friend is credited
/// once, in the kind that fit the creator's plan when Cue learned of it, and stays so. Pure: the count of friends comes from the server
/// (`ReferralStatus.rewarded`), the plan from `StoreManager`.
nonisolated struct ReferralRewards: Codable, Equatable, Sendable {
    static let exportsPerFriend = 3
    static let ultraScriptsPerFriend = 5
    /// The most friends who earn a reward (the server's `rewardedFriends`).
    static let friendsRewarded = 5

    var friendsAsExports = 0
    var friendsAsUltraScripts = 0

    var friendsCredited: Int { friendsAsExports + friendsAsUltraScripts }
    var bonusExports: Int { friendsAsExports * Self.exportsPerFriend }
    var bonusUltraScripts: Int { friendsAsUltraScripts * Self.ultraScriptsPerFriend }

    /// The friends the server rewards that aren't credited yet, credited now: as Ultra AI scripts when `asUltraScripts`, else as exports.
    /// Returns how many were new.
    mutating func credit(rewarded: Int, asUltraScripts: Bool) -> Int {
        let new = max(0, rewarded - friendsCredited)
        if asUltraScripts {
            friendsAsUltraScripts += new
        } else {
            friendsAsExports += new
        }
        return new
    }
}
