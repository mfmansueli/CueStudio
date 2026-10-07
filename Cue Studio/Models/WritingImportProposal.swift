//
//  WritingImportProposal.swift
//  Cue Studio
//

import Foundation

/// What the creator reviews after importing their writing, and all of what is kept if they accept: the findings they can switch on and off, the
/// excerpts, and the measures. Nothing is saved until they say so.
nonisolated struct WritingImportProposal: Hashable, Sendable {
    var findings: [WritingFinding] = []
    var excerpts: [VoiceExcerpt] = []
    var fingerprint: VoiceFingerprint?
    var pieceCount = 0
    var wordCount = 0
    /// The language it is written in ("en").
    var language: String?
    /// More than one language was found: only the main one was read.
    var isMixedLanguage = false
    /// Texts left out of the excerpts because of words Apple Intelligence won't learn from.
    var blockedPieces = 0
    /// Apple Intelligence read the style too (the tone, the topics, who is watching).
    var usedAppleIntelligence = false

    /// Something worth saving came out of it.
    var hasAnything: Bool { findings.contains { $0.isOn } || !excerpts.isEmpty }
}
