//
//  ScriptSpeechTracker.swift
//  Cue Studio
//

import Foundation

/// Follows a reading of the script. Each time the transcription changes, the latest words heard
/// are aligned with the words around the current position, and `position` moves to the word after
/// the last one read.
///
/// The alignment tolerates misheard words, a word still being said and skipped lines. It never
/// moves back on its own (re-reading a sentence just holds the text), and talk that isn't in the
/// script matches nothing, so the text waits.
nonisolated struct ScriptSpeechTracker: Equatable, Sendable {
    let words: [String]
    /// The language it's read in: what's heard is cut into words the way the script was
    /// (`ScriptWords(text:language:)`).
    let language: CueLanguage?
    /// Index of the next word to read; `words.count` once the whole script has been read.
    private(set) var position = 0
    /// What an exact match of each script word is worth (`exactMatch`, or `commonMatch` for the words
    /// the script keeps repeating: its "the", "de", "e").
    private let weights: [Int]

    /// Recent words heard that take part in a match: enough context to tell repeated phrases apart.
    private static let heardWindow = 8
    /// Already-read words the match may overlap, so the context of what was just read counts.
    private static let lookBehind = 6
    /// How far ahead a match may land (a skipped sentence or two).
    private static let lookAhead = 60

    private static let exactMatch = 2
    /// A word that appears this many times in the script is common in it.
    private static let commonRepeats = 3
    /// Exact matches of common words count for less, so a lone one never moves the text: talk that
    /// isn't in the script ("so", "and", "the" while the creator thinks aloud) matches them anywhere, and
    /// scattered ones used to add up to a jump of dozens of words. Reading the script in order still
    /// finds its rarer words, which carry the match. Measured on synthetic readings with off-script
    /// filler (`VoiceFollowingRobustnessTests`): the text ended up to 47 words ahead of the reader (95th
    /// percentile, English) before, 4 after, with a clean reading still followed to the end.
    private static let commonMatch = 1
    private static let closeMatch = 1
    private static let mismatch = -1
    private static let gap = -1

    init(words: [String], language: CueLanguage? = nil) {
        self.words = words
        self.language = language
        var counts: [String: Int] = [:]
        for word in words { counts[word, default: 0] += 1 }
        weights = words.map { counts[$0, default: 0] >= Self.commonRepeats ? Self.commonMatch : Self.exactMatch }
    }

    mutating func reset(to position: Int) {
        self.position = min(max(0, position), words.count)
    }

    /// Takes the transcription so far (only its last words matter). Returns true when the
    /// position moved.
    @discardableResult
    mutating func hear(_ transcript: String) -> Bool {
        let heard = Array(ScriptWords.tokens(in: transcript, language: language).suffix(Self.heardWindow))
        guard !heard.isEmpty, position < words.count else { return false }
        let window = max(0, position - Self.lookBehind)..<min(words.count, position + Self.lookAhead)
        guard let lastRead = bestMatch(for: heard, in: window), lastRead + 1 > position else { return false }
        position = lastRead + 1
        return true
    }

    // MARK: - Alignment

    /// Local alignment (Smith–Waterman) of the heard words against the window, anchored at the
    /// newest word heard. Returns the index of the script word it ends on, or nil when nothing
    /// matches convincingly for the distance it would move.
    private func bestMatch(for heard: [String], in window: Range<Int>) -> Int? {
        let script = Array(words[window])
        let worth = Array(weights[window])
        var previous = [Int](repeating: 0, count: script.count + 1)
        for word in heard {
            var row = [Int](repeating: 0, count: script.count + 1)
            for column in 1...script.count {
                let diagonal = previous[column - 1] + Self.similarity(word, script[column - 1], exact: worth[column - 1])
                row[column] = max(0, diagonal, previous[column] + Self.gap, row[column - 1] + Self.gap)
            }
            previous = row
        }
        // The last row ends on the newest heard word, so the match reflects where the reader is now.
        var best: (index: Int, score: Int)?
        for column in 1...script.count where previous[column] > 0 {
            let index = window.lowerBound + column - 1
            let score = previous[column]
            guard score >= Self.requiredScore(forMovingBy: index + 1 - position) else { continue }
            if let current = best {
                let isCloser = abs(index + 1 - position) < abs(current.index + 1 - position)
                guard score > current.score || (score == current.score && isCloser) else { continue }
            }
            best = (index, score)
        }
        return best?.index
    }

    /// A word or two ahead needs one match; bigger jumps need more agreement, so a stray common
    /// word ("the") can't pull the text far ahead.
    private static func requiredScore(forMovingBy distance: Int) -> Int {
        switch distance {
        case ...4: exactMatch
        case ...20: 2 * exactMatch
        default: 3 * exactMatch
        }
    }

    private static func similarity(_ heard: String, _ word: String, exact: Int) -> Int {
        if heard == word { return exact }
        // A word still being said ("teleprom") or heard slightly off ("colour" for "color").
        if heard.count >= 3, word.hasPrefix(heard) { return closeMatch }
        if min(heard.count, word.count) >= 4, editDistance(heard, word) <= (word.count >= 8 ? 2 : 1) {
            return closeMatch
        }
        return mismatch
    }

    private static func editDistance(_ lhs: String, _ rhs: String) -> Int {
        let a = Array(lhs), b = Array(rhs)
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var row = [i] + [Int](repeating: 0, count: b.count)
            for j in 1...b.count {
                row[j] = min(previous[j] + 1, row[j - 1] + 1, previous[j - 1] + (a[i - 1] == b[j - 1] ? 0 : 1))
            }
            previous = row
        }
        return previous[b.count]
    }
}
