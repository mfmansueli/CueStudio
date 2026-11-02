//
//  CatchphraseRotation.swift
//  Cue Studio
//

import Foundation

/// Which of the creator's catchphrases a script is offered (the owner's B10, 02/11/2026; `reports/entradas-do-criador-2026-11-01-completo.md`
/// §11, A9): at most `perScript`, none twice, taking turns so that every one comes round. Five phrases go 1 2 3, then 4 5 1, then 2 3 4: two
/// scripts in a row offer all five, and none is offered in every script.
nonisolated enum CatchphraseRotation {
    static let perScript = 3

    /// The phrases offered at `turn` (the scripts written before this one): all of them when there are no more than `perScript`.
    static func phrases(_ phrases: [String], at turn: Int) -> [String] {
        let kept = Array(phrases.prefix(VoiceLimits.phrases))
        guard kept.count > perScript else { return kept }
        let start = (max(0, turn) * perScript) % kept.count
        return (0..<perScript).map { kept[(start + $0) % kept.count] }
    }

    /// Whether the phrases take turns at all (what "What Cue sends" explains).
    static func rotates(_ phrases: [String]) -> Bool {
        min(phrases.count, VoiceLimits.phrases) > perScript
    }
}
