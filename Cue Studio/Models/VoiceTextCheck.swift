//
//  VoiceTextCheck.swift
//  Cue Studio
//

import Foundation

/// What checking a word or phrase the creator typed into My Cue Voice found (04 · F9).
nonisolated enum VoiceTextCheck: Equatable, Sendable {
    /// Fine as it is (trimmed).
    case accepted(String)
    /// Under 2 characters.
    case tooShort
    /// Over 40 characters.
    case tooLong
    /// A word Apple Intelligence won't write: it is not saved.
    case blocked
    /// Already in the list: the existing one gets selected.
    case duplicate(existing: String)
    /// Close to a known option: "Did you mean "{suggestion}"? Use · Keep mine".
    case typo(suggestion: String, original: String)

    /// What to tell the creator; nil when the text is fine.
    var message: String? {
        switch self {
        case .accepted: nil
        case .tooShort: String(localized: "Add a word or two.")
        case .tooLong: String(localized: "Keep it under 40 characters.")
        case .blocked: String(localized: "Apple Intelligence can’t use this word.")
        case .duplicate: String(localized: "Already added.")
        case .typo(let suggestion, _): String(localized: "Did you mean “\(suggestion)”?")
        }
    }
}
