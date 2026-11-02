//
//  VoiceTypedAnswerEvent.swift
//  Cue Studio
//

import Foundation

/// A "+ Something else" answer, as Analytics counts it (the owner's B14, 02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md` §11):
/// which question, and whether what was typed is one of the list's options (or a typo of one) or something the list doesn't have. Never the
/// text. Sent only with "Help improve Cue" on (`AppServices`). It says which lists are missing what creators reach for.
nonisolated struct VoiceTypedAnswerEvent: Hashable, Sendable {
    /// `VoiceQuestion.rawValue` ("endings", "role", "audience").
    let question: String
    let matchesAnOption: Bool

    var parameters: [String: String] {
        ["question": question, "outcome": matchesAnOption ? "matched" : "no_match"]
    }

    /// `raw` against the labels the question offers (in the interface's language, as the creator reads them).
    init(question: VoiceQuestion, raw: String, options: [String]) {
        self.question = question.rawValue
        switch VoiceTextValidator.check(raw, existing: options, vocabulary: options) {
        case .duplicate, .typo: matchesAnOption = true
        default: matchesAnOption = false
        }
    }
}
