//
//  WritingAnalysis.swift
//  Cue Studio
//

import Foundation

/// What Cue found out of the writing the creator imported, before anything is kept: the measures, the habits it could name and the excerpts it
/// would keep. `WritingImportProposal` turns it into what the creator reviews.
nonisolated struct WritingAnalysis: Hashable, Sendable {
    var pieceCount = 0
    var wordCount = 0
    /// The language most of it is written in, and how much of the words each language has (0...1).
    var language: String?
    var languageShares: [String: Double] = [:]
    var fingerprint: VoiceFingerprint?

    var sentences: SentenceLength?
    var words: WordLevel?
    var energy: VoiceEnergy?
    var swearing: Swearing?
    var speaksAs: SpeaksAs?
    var length: VideoLength?
    var phrases: [String] = []
    /// The catalog's English ids that come back often enough to be a habit, most common first.
    var openings: [String] = []
    var endings: [String] = []
    /// How many texts each opening and ending was found in.
    var openingCounts: [String: Int] = [:]
    var endingCounts: [String: Int] = [:]
    var excerpts: [VoiceExcerpt] = []
    /// Texts left out of the excerpts because they hold words Apple Intelligence won't learn from.
    var blockedPieces = 0

    /// The creator mixes languages: a second one has a fifth of the words or more.
    var isMixedLanguage: Bool { languageShares.filter { $0.value >= 0.2 }.count > 1 }

    /// Nothing usable came out of it.
    var isEmpty: Bool { pieceCount == 0 }
}
