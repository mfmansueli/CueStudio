//
//  CleanUpFindings.swift
//  Cue Studio
//

import Foundation

/// What Clean up found in one recording (`TakeEditing.cleanUpFindings`): its suggestions, how sure it could be of the pauses among
/// them (`PauseHearing`, so Pauses can tell "no long pauses" from "too much background sound to tell"), and what it learned about
/// the words (`CleanUpHearing`: whether they were heard, and in which language).
nonisolated struct CleanUpFindings: Hashable, Sendable {
    var suggestions: [CleanUpSuggestion]
    var pauseHearing: PauseHearing = .clear
    var hearing = CleanUpHearing()
}
