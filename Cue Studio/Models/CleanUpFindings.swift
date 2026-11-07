//
//  CleanUpFindings.swift
//  Cue Studio
//

import Foundation

/// What Clean Up found in one recording: its suggestions and how sure it could be of the pauses among them (`PauseHearing`), so
/// Pauses can tell "no long pauses" from "too much background sound to tell".
nonisolated struct CleanUpFindings: Hashable, Sendable {
    var suggestions: [CleanUpSuggestion]
    var pauseHearing: PauseHearing = .clear
}
