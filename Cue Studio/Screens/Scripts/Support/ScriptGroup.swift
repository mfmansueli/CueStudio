//
//  ScriptGroup.swift
//  Cue Studio
//

import Foundation

/// A group of the Scripts list (v29): READY TO RECORD, DRAFTS or RECORDED. Within a group the order is the
/// library's (the last edited first); a group with no script is not there at all.
nonisolated struct ScriptGroup: Identifiable, Equatable, Sendable {
    let state: ScriptState
    let scripts: [Script]

    var id: ScriptState { state }

    /// "READY TO RECORD · 3", "DRAFTS · 4 · IN PROGRESS", "RECORDED · 2".
    var count: Int { scripts.count }

    static func groups(of scripts: [Script], takeCount: (UUID) -> Int) -> [ScriptGroup] {
        let byState = Dictionary(grouping: scripts) { $0.state(takeCount: takeCount($0.id)) }
        return ScriptState.allCases
            .sorted { $0.sortOrder < $1.sortOrder }
            .compactMap { state in byState[state].map { ScriptGroup(state: state, scripts: $0) } }
    }
}
