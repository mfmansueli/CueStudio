//
//  IdeaInspiration.swift
//  Cue Studio
//

import Foundation

/// What the creator wrote lately, as the ideas grow from it: the notes waiting in their Logbook (what they said or typed on the spur of the moment is the
/// most honest sign of what interests them) and the titles of their latest scripts.
nonisolated enum IdeaInspiration {
    /// At most this many things, the notes first.
    static let limit = 8

    static func recent(scripts: [Script], notes: [LogbookEntry]) -> [String] {
        let fromNotes = notes.prefix(5).map(\.text)
        let fromScripts = scripts.sorted { $0.updatedAt > $1.updatedAt }.map(\.title)
            .filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }.prefix(4)
        var seen = Set<String>()
        return (fromNotes + fromScripts).map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }.prefix(limit).map { $0 }
    }
}
