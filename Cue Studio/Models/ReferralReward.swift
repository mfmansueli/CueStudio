//
//  ReferralReward.swift
//  Cue Studio
//

import Foundation

/// What one invited friend's first export earns the creator: exports on the free plan, Ultra AI scripts on Cue Pro (`ReferralRewards`).
nonisolated enum ReferralReward: Equatable, Sendable {
    case exports
    case ultraScripts

    /// How many for one friend.
    var perFriend: Int {
        switch self {
        case .exports: ReferralRewards.exportsPerFriend
        case .ultraScripts: ReferralRewards.ultraScriptsPerFriend
        }
    }
}
