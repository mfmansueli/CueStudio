//
//  CleanUpFindings.swift
//  Cue Studio
//

import Foundation

/// What listening to one recording gives Clean up (`TakeEditing.cleanUpFindings`): its suggestions, and what it learned on the
/// way (`CleanUpHearing`: the words' language, or that the sound was inconclusive).
nonisolated struct CleanUpFindings: Hashable, Sendable {
    var suggestions: [CleanUpSuggestion]
    var hearing: CleanUpHearing

    init(suggestions: [CleanUpSuggestion], hearing: CleanUpHearing = CleanUpHearing()) {
        self.suggestions = suggestions
        self.hearing = hearing
    }
}
