//
//  WhatsNewCatalog.swift
//  Cue Studio
//

import Foundation

/// The features each version brings that are worth a "What's new" (with the creator's yes to that category): only something real and
/// usable in the version that announces it, told once per version, and only to someone who updated from an older one (a fresh install
/// has nothing "new"). 1.0 is the first version, so it announces nothing; entries are added with the version that ships them.
nonisolated enum WhatsNewCatalog {
    struct Entry: Hashable, Sendable {
        /// "1.1": the version it arrives in.
        let version: String
        /// Stable and unique: it is remembered as announced.
        let id: String
        let destination: NotificationDestination
    }

    static let all: [Entry] = []

    /// What `current` announces to someone who last ran `previous` (nil: a fresh install, nothing), minus what was already announced.
    static func announcements(current: String, previous: String?, announced: [String], catalog: [Entry] = all) -> [Entry] {
        guard let previous, previous.compare(current, options: .numeric) == .orderedAscending else { return [] }
        return catalog.filter { entry in
            !announced.contains(entry.id)
                && entry.version.compare(previous, options: .numeric) == .orderedDescending
                && entry.version.compare(current, options: .numeric) != .orderedDescending
        }
    }
}
