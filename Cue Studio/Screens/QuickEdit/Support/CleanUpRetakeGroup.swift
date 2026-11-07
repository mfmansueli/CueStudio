//
//  CleanUpRetakeGroup.swift
//  Cue Studio
//

import Foundation

/// The tries at one script line said more than once (`ScriptRetakeDetector`), in the order said, as Words shows them: listen
/// to each and keep one; the others are marked to go.
struct CleanUpRetakeGroup: Identifiable, Hashable {
    let id: UUID
    /// The line of the script, as written.
    let line: String
    let tries: [CleanUpSuggestion]
}
