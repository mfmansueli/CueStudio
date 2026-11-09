//
//  TakePlatformMigration.swift
//  Cue Studio
//

import Foundation

/// Once, when a library from before videos were told apart by network (`TakeVideoKey`) opens: every take of a script that is still there
/// gets the script's current network, which is where Takes already filed it, so nothing moves on screen. A take whose script is gone keeps
/// the network it was recorded with; freestyle and imported takes keep theirs (nil stays nil: they show under All only). Only the network
/// changes: the star, the edits, the drafts, the exports, the share queue, the posts and the reminders all live per take. Pure.
nonisolated enum TakePlatformMigration {
    /// The version written once it ran (`DefaultsKey.takeNetworkMigration`); a later change of the rule asks for a new one.
    static let version = 1

    static func migrated(_ takes: [Take], scriptPlatform: (UUID) -> Platform?) -> (takes: [Take], changed: Int) {
        var changed = 0
        let result = takes.map { take -> Take in
            guard let scriptID = take.scriptID, let platform = scriptPlatform(scriptID), take.platform != platform else { return take }
            var moved = take
            moved.platform = platform
            changed += 1
            return moved
        }
        return (result, changed)
    }
}
