//
//  ReferralStatus.swift
//  Cue Studio
//

import Foundation

/// The creator's invites, as Cue's server counts them (`referral` in `server/functions`): their code, the friends who typed it and the friends
/// who then exported their first video. Only the server sets these numbers (ARCHITECTURE §2.7); the app reads them.
nonisolated struct ReferralStatus: Codable, Equatable, Sendable {
    /// Six characters, without I, O, 0 or 1.
    var code: String
    /// Friends who typed the code.
    var joined: Int
    /// Friends who then exported their first video.
    var activated: Int
    /// Friends whose first export earned a reward: `activated`, up to `limit`.
    var rewarded: Int
    /// The most friends who earn a reward.
    var limit: Int
    /// How the server credited the rewarded friends: as exports (free plan), or as Ultra AI scripts (a Cue Pro it verified). Nil from a server
    /// before it decided the split; the app then credits by its own plan.
    var friendsAsExports: Int?
    var friendsAsUltraScripts: Int?

    var hasReachedLimit: Bool { rewarded >= limit }
}
