//
//  ScriptPageRules.swift
//  Cue Studio
//

import Foundation

/// What Done and leaving do on the script page (04 · F2), as pure rules.
nonisolated enum ScriptPageRules {
    enum DoneOutcome: Equatable, Sendable {
        /// No text: nothing is saved ("Nothing to save yet").
        case nothingToSave
        /// A format's sections are still empty: "{n} sections are still empty." Done anyway / Keep writing.
        case confirmEmptySections(Int)
        case finish
    }

    /// How many of the format's sections have no words yet. A script with no format has no sections to fill.
    static func emptySections(text: String, type: ScriptType?) -> Int {
        guard let type else { return 0 }
        let filled = CueParser.paragraphs(in: text).count
        return max(0, type.structure.blocks.count - filled)
    }

    static func done(text: String, type: ScriptType?) -> DoneOutcome {
        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .nothingToSave }
        let empty = emptySections(text: text, type: type)
        return empty > 0 ? .confirmEmptySections(empty) : .finish
    }

    /// Leaving with edits and no Done turns a script that wasn't recorded into a draft, with the toast "Saved as draft".
    /// A recorded script stays recorded.
    static func leavesAsDraft(state: ScriptState, wasEdited: Bool) -> Bool {
        wasEdited && state != .recorded
    }
}
