//
//  WritingAnalyzer.swift
//  Cue Studio
//

import Foundation

/// Reads the creator's imported writing and says how they write: measures first (sentence length, questions, exclamations, emoji, "I" or
/// "we", length), then the habits a few texts can show (the phrases they repeat, how they open and end), then the excerpts worth keeping. No
/// model runs here: it is the same on every iPhone, instant, and has nothing to refuse.
nonisolated enum WritingAnalyzer {
    /// Habits (phrases, openings, endings) need at least this many texts: two can agree by chance.
    static let minimumPiecesForHabits = PhraseMiner.minimumPieces
    /// Fewer words than this and a measure is not offered as a style.
    static let minimumWordsForStyle = 100

    static func analyze(_ pieces: [WritingPiece], now: Date = .now) -> WritingAnalysis {
        var analysis = WritingAnalysis()
        let pieces = pieces.filter { !$0.text.isEmpty }
        analysis.pieceCount = pieces.count
        guard !pieces.isEmpty else { return analysis }

        var wordsByLanguage: [String: Int] = [:]
        for piece in pieces {
            if let language = piece.language { wordsByLanguage[language, default: 0] += piece.wordCount }
        }
        let languageWords = max(1, wordsByLanguage.values.reduce(0, +))
        analysis.wordCount = pieces.reduce(0) { $0 + $1.wordCount }
        analysis.languageShares = wordsByLanguage.mapValues { Double($0) / Double(languageWords) }
        let dominant = wordsByLanguage.max { $0.value != $1.value ? $0.value < $1.value : $0.key > $1.key }?.key
        analysis.language = dominant
        // The measures are those of one language: a text in another is left out of them.
        let own = pieces.filter { $0.language == dominant }
        guard !own.isEmpty else { return analysis }

        let counts = count(own, language: dominant)
        analysis.blockedPieces = own.filter { VoiceTextValidator.isBlocked($0.text) }.count
        let fingerprint = counts.sentences >= 3 && counts.words >= 40 ? counts.fingerprint(language: dominant, pieces: own, now: now) : nil
        analysis.fingerprint = fingerprint
        deliver(counts, fingerprint: fingerprint, language: dominant, blocked: analysis.blockedPieces, into: &analysis)

        if own.count >= minimumPiecesForHabits {
            analysis.phrases = PhraseMiner.phrases(in: own, language: dominant)
            habits(of: own, language: dominant, into: &analysis)
            analysis.length = usualLength(of: own)
        }
        analysis.excerpts = ExcerptSelector.excerpts(from: own, language: dominant, fingerprint: fingerprint, phrases: analysis.phrases)
        return analysis
    }

    // MARK: - Counting

    private struct Counts {
        var sentences = 0
        var words = 0
        var questions = 0
        var exclamations = 0
        var emoji = 0
        var letters = 0
        var singular = 0
        var plural = 0
        var slang = 0
        var mild = 0

        func fingerprint(language: String?, pieces: [WritingPiece], now: Date) -> VoiceFingerprint {
            let sizes = pieces.map(\.wordCount).sorted()
            return VoiceFingerprint(
                language: language ?? "und", pieces: pieces.count, words: words,
                wordsPerSentence: Double(words) / Double(max(1, sentences)),
                questionShare: Double(questions) / Double(max(1, sentences)),
                exclamationShare: Double(exclamations) / Double(max(1, sentences)),
                emojiPer100Words: Double(emoji) * 100 / Double(max(1, words)),
                averageWordLength: Double(letters) / Double(max(1, words)),
                singularWords: singular, pluralWords: plural, medianWords: sizes[sizes.count / 2], measuredAt: now
            )
        }
    }

    private static func count(_ pieces: [WritingPiece], language: String?) -> Counts {
        let lexicon = WritingLexicon.lexicon(for: language)
        var counts = Counts()
        for piece in pieces {
            for sentence in WritingText.sentences(in: piece.text, language: language) {
                counts.sentences += 1
                if WritingText.isQuestion(sentence) { counts.questions += 1 }
                if WritingText.isExclamation(sentence) { counts.exclamations += 1 }
                for word in WritingText.words(in: sentence, language: language) {
                    counts.words += 1
                    counts.letters += word.key.filter(\.isLetter).count
                    guard let lexicon else { continue }
                    if lexicon.singular.contains(word.key) { counts.singular += 1 }
                    if lexicon.plural.contains(word.key) { counts.plural += 1 }
                    if lexicon.slang.contains(word.key) { counts.slang += 1 }
                    if lexicon.mildSwearing.contains(word.key) { counts.mild += 1 }
                }
            }
            counts.emoji += WritingText.emojiCount(in: piece.text)
        }
        return counts
    }

    // MARK: - What the measures say

    private static func deliver(
        _ counts: Counts, fingerprint: VoiceFingerprint?, language: String?, blocked: Int, into analysis: inout WritingAnalysis
    ) {
        let lexicon = WritingLexicon.lexicon(for: language)
        if let fingerprint, fingerprint.words >= minimumWordsForStyle {
            if !WritingLexicon.isUnspaced(language) {
                let perSentence = fingerprint.wordsPerSentence
                analysis.sentences = perSentence <= 11 ? .short : (perSentence >= 18 ? .long : .mixed)
            }
            if fingerprint.exclamationShare >= 0.25 || fingerprint.emojiPer100Words >= 2 {
                analysis.energy = .high
            } else if fingerprint.exclamationShare <= 0.04, fingerprint.emojiPer100Words == 0 {
                analysis.energy = .calm
            } else {
                analysis.energy = .balanced
            }
            if let lexicon {
                let slangRate = Double(counts.slang) * 100 / Double(fingerprint.words)
                if slangRate >= 1.5 {
                    analysis.words = .someSlang
                } else if fingerprint.averageWordLength >= lexicon.expertWordLength {
                    analysis.words = .expertTerms
                } else if fingerprint.averageWordLength <= lexicon.plainWordLength {
                    analysis.words = .plain
                }
            }
        }
        // Strong swearing is never written whatever they say; a creator who uses it or the mild kind gets "mild only". Never swearing is
        // only claimed of a long text with none.
        if blocked > 0 || counts.mild >= 2 {
            analysis.swearing = .mild
        } else if counts.words >= 400 {
            analysis.swearing = .never
        }
        if lexicon != nil {
            if counts.plural >= 6, Double(counts.plural) > Double(counts.singular) * 1.5 {
                analysis.speaksAs = .we
            } else if counts.singular >= 6, Double(counts.singular) > Double(counts.plural) * 1.5 {
                analysis.speaksAs = .i
            }
        }
    }

    // MARK: - Habits

    private static func habits(of pieces: [WritingPiece], language: String?, into analysis: inout WritingAnalysis) {
        var openings: [String: Int] = [:]
        var endings: [String: Int] = [:]
        for piece in pieces {
            if let opening = WritingOpeningReader.opening(of: piece.text, language: language) { openings[opening, default: 0] += 1 }
            for ending in WritingOpeningReader.endings(of: piece.text, language: language) { endings[ending, default: 0] += 1 }
        }
        let needed = max(2, Int((Double(pieces.count) * 0.3).rounded(.up)))
        func habitual(_ counts: [String: Int], limit: Int) -> [String] {
            counts.filter { $0.value >= needed }
                .sorted { $0.value != $1.value ? $0.value > $1.value : $0.key < $1.key }
                .prefix(limit).map(\.key)
        }
        analysis.openingCounts = openings
        analysis.endingCounts = endings
        analysis.openings = habitual(openings, limit: VoiceLimits.openings)
        analysis.endings = habitual(endings, limit: VoiceLimits.endings)
    }

    /// The video length their texts would take at a natural pace: the middle text, not the longest. Captions and notes are too short to say.
    private static func usualLength(of pieces: [WritingPiece]) -> VideoLength? {
        let sizes = pieces.map(\.wordCount).sorted()
        let median = sizes[sizes.count / 2]
        guard median >= 30 else { return nil }
        let seconds = Double(median) / 150 * 60
        switch seconds {
        case ..<30: return .under30
        case ..<60: return .thirtyToSixty
        case ..<180: return .oneToThree
        default: return .longer
        }
    }
}
