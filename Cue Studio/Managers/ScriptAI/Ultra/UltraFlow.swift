//
//  UltraFlow.swift
//  Cue Studio
//

import Foundation

/// The passes an Ultra script goes through: the draft and its polish, or (`checked`) a call of its own for the claims in between
/// (`UltraInstructions.checker`), which Codex's lab asked for when Gemini's polish missed wrong technical claims.
nonisolated enum UltraFlow: String, CaseIterable, Hashable, Sendable {
    /// The draft, then its polish in the creator's voice (which also corrects claims).
    case polished
    /// The draft, then its claims checked on their own, then the polish in the creator's voice.
    case checked

    /// The passes every script takes (the lab picks its own). With Claude through Cue's server the separate check doesn't pay: in the blind
    /// study of 04/11/2026 (1,047 scripts, three judges, `tools/ultra/study`) Opus at low effort in two calls scored as Opus low in three
    /// (89.5 and 89.9 of 100), costs a third less (US$ 0.054 a script) and was the owner's pick in their own blind reading (6 of 10 ideas).
    static let standard = UltraFlow.polished

    /// The calls a script takes, each counted against the lab's cap.
    var calls: Int { self == .checked ? 3 : 2 }
}
