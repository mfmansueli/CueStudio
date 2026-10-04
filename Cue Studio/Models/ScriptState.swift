//
//  ScriptState.swift
//  Cue Studio
//

import Foundation

/// Where a script stands (v29): RECORDED once it has a take, READY when the creator (or the AI delivering a complete
/// script) finished it, DRAFT otherwise. Derived, never set by hand: the stored part is `Script.isFinished`.
/// Shape, cues and "Remove all cues" never change it.
nonisolated enum ScriptState: String, CaseIterable, Sendable {
    case ready, draft, recorded

    /// The single rule (04 · F2): ≥ 1 take → recorded · otherwise finished → ready · otherwise draft.
    static func resolve(isFinished: Bool, takeCount: Int) -> ScriptState {
        if takeCount > 0 { return .recorded }
        return isFinished ? .ready : .draft
    }

    /// The order of the groups on Scripts.
    var sortOrder: Int {
        switch self {
        case .ready: 0
        case .draft: 1
        case .recorded: 2
        }
    }
}

nonisolated extension Script {
    /// The state with `takeCount` takes recorded from this script.
    func state(takeCount: Int) -> ScriptState {
        ScriptState.resolve(isFinished: isFinished, takeCount: takeCount)
    }

    /// "CHANGED SINCE TAKE n": the script moved on after its latest take (a take keeps the version it was read from).
    func changedSince(latestTakeVersion: Int?) -> Bool {
        guard let latestTakeVersion else { return false }
        return version > latestTakeVersion
    }
}
