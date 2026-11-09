//
//  TakeVideoKey.swift
//  Cue Studio
//

import Foundation

/// Which video a take belongs to (owner, 09/11/2026): the takes of one script recorded for the same network (`Take.platform`, the network
/// the recording was made for) are one video, so a script recorded for Reels and again for Shorts has two videos; a take without a script
/// (freestyle, imported) is a video of its own. Every place that groups takes into videos asks this, never the script alone: Takes and its
/// network chips, the review's strip ("TAKE 2 OF 3"), its stage and ★, Pick best, the notifications' facts, the first star, the first voyage
/// and the recorder's last take. Where a video was posted (`ShareRecord.platforms`) never changes it.
nonisolated enum TakeVideoKey: Hashable, Sendable {
    /// A script's takes for one network (nil: a take from before every take kept its network, `TakePlatformMigration`).
    case script(UUID, Platform?)
    /// A freestyle or imported take: alone.
    case alone(UUID)

    init(_ take: Take) {
        if let scriptID = take.scriptID {
            self = .script(scriptID, take.platform)
        } else {
            self = .alone(take.id)
        }
    }

    /// The video's id in Takes: the script's id, with the network after it ("<script>.reels"); a take alone, its own id.
    var id: String {
        switch self {
        case .script(let scriptID, let platform): platform.map { "\(scriptID.uuidString).\($0.rawValue)" } ?? scriptID.uuidString
        case .alone(let takeID): takeID.uuidString
        }
    }

    /// The takes of `takes` in this video, in their order.
    func takes(in takes: [Take]) -> [Take] {
        takes.filter { TakeVideoKey($0) == self }
    }

    /// Videos among `takes`: how many keys they have.
    static func count(in takes: [Take]) -> Int {
        Set(takes.map(TakeVideoKey.init)).count
    }
}
