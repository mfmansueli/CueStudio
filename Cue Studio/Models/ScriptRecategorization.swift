//
//  ScriptRecategorization.swift
//  Cue Studio
//

import Foundation

/// A script moved from one network to another (its page's network chip, Details › Create for): what its takes do, with no question asked
/// (owner, 09/11/2026). The video it had for the old network follows it, unless that video was already posted (it went out as a video for
/// the old network) or the script already has a video for the new one (they would merge into one): then it stays where it was. Takes
/// recorded for any other network are versions of their own and never move. Pure.
nonisolated struct ScriptRecategorization: Equatable, Sendable {
    /// Why the old network's video stayed.
    enum Stay: Equatable, Sendable {
        /// Posted or exported: it went out as that network's video.
        case posted
        /// The new network already has a video of this script.
        case newNetworkHasOne
    }

    let from: Platform
    let to: Platform
    /// The takes that follow the script.
    let moving: Set<UUID>
    /// Set when the old network's video stayed.
    let stay: Stay?

    /// - Parameters:
    ///   - takes: every take of the script.
    ///   - wasPosted: whether a take went out (a confirmed post, `ShareRecord`; or saved and shared, `Take.isExported`).
    init(takes: [Take], from: Platform, to: Platform, wasPosted: (Take) -> Bool) {
        self.from = from
        self.to = to
        let video = from == to ? [] : takes.filter { $0.platform == from }
        if video.isEmpty {
            moving = []
            stay = nil
        } else if video.contains(where: wasPosted) {
            moving = []
            stay = .posted
        } else if takes.contains(where: { $0.platform == to }) {
            moving = []
            stay = .newNetworkHasOne
        } else {
            moving = Set(video.map(\.id))
            stay = nil
        }
    }

    /// The script had a video for the old network: the toast says what became of it, with Undo. Nil when it had none (the script just moves,
    /// as a script with no takes does).
    var message: String? {
        switch stay {
        case nil:
            moving.isEmpty ? nil : String(localized: "Moved to \(to.label)")
        case .posted:
            String(localized: "Moved to \(to.label) · \(from.label) video stays (already posted)")
        case .newNetworkHasOne:
            String(localized: "Moved to \(to.label) · \(from.label) video stays (\(to.label) already has one)")
        }
    }
}
