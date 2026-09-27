//
//  TakeGroup.swift
//  Cue Studio
//

import Foundation

/// Takes of one script (or all freestyle recordings), newest first.
nonisolated struct TakeGroup: Hashable, Identifiable, Sendable {
    /// The script ID, or nil for freestyle recordings.
    let scriptID: UUID?
    let title: String
    let takes: [Take]

    var id: String { scriptID?.uuidString ?? "freestyle" }

    /// Groups takes by script, ordered by each group's newest take.
    static func groups(from takes: [Take]) -> [TakeGroup] {
        var order: [UUID?] = []
        var byScript: [UUID?: [Take]] = [:]
        for take in takes.sorted(by: { $0.recordedAt > $1.recordedAt }) {
            if byScript[take.scriptID] == nil { order.append(take.scriptID) }
            byScript[take.scriptID, default: []].append(take)
        }
        return order.map { scriptID in
            let group = byScript[scriptID] ?? []
            let title = scriptID == nil
                ? String(localized: "Freestyle recordings")
                : (group.first?.scriptTitle ?? String(localized: "Untitled script"))
            return TakeGroup(scriptID: scriptID, title: title, takes: group)
        }
    }
}
