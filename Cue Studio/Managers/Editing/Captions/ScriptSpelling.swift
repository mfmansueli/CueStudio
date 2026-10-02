//
//  ScriptSpelling.swift
//  Cue Studio
//

import Foundation

/// What the script lends to the words that were heard in a take.
///
/// The voice always decides **what was said and when**: improvised words stay, skipped lines never
/// appear, a different number or a negation is never replaced. The script only decides **how a
/// heard word is written** (spelling, accents, capitals, punctuation), and how much it is trusted
/// depends on the take:
/// - **Read from the script** (most heard words line up with it, in order): the recognizer's slips
///   are fixed. Short words that sit between words that line up are spelled as written, and a word
///   (or two) that differs from the script's by a letter or two between words that line up is
///   written as the script has it ("mostra" → "mostrar").
/// - **Improvised** (little lines up): only words that line up reliably take the script's spelling,
///   and a heard word is replaced only when it is nearly the same word.
/// Words are compared by `WordTokenizer.key` (case, accents, width and the letters recognizers
/// write in more than one way are folded), so Arabic, Hindi, Japanese, Chinese and Thai are
/// compared the same way as Latin scripts.
nonisolated enum ScriptSpelling {
    struct Result: Equatable, Sendable {
        var words: [CaptionWord]
        /// Most of what was heard lines up with the script: the take was read from it.
        var followsScript: Bool
        /// Heard words that line up with the script, 0 to 1.
        var coverage: Double
    }

    /// Share of the heard words that must line up for the take to count as read from the script.
    static let followingCoverage = 0.6
    /// Fewest heard words, and fewest matches, before a take can count as read from the script.
    static let followingMinimumWords = 4
    static let followingMinimumMatches = 3
    /// Longest gap, in words, that is corrected word by word.
    static let longestGap = 3
    /// How alike two words must be (1 is identical) for the heard one to be written as the script's.
    static let similarity = (improvised: 0.75, following: 0.65)
    /// How alike two stretches must be when the same letters are split into a different number of words.
    static let stretchSimilarity = (improvised: 0.8, following: 0.7)
    /// Fewest letters in a word that may be replaced by a similar one, in spaced and unspaced scripts.
    static let minimumLetters = (spaced: 4, unspaced: 2)
    /// Most letters in a stretch re-split into other words.
    static let stretchLetters = 2...12

    /// `heard` with the script's spelling where it applies; the same words and times, except that a
    /// stretch re-split into other words shares its time (and is marked estimated).
    static func apply(to heard: [CaptionWord], script: String, language: CueLanguage? = nil) -> Result {
        let written = CaptionText.words(in: CueParser.stripCues(script), language: language)
        guard !heard.isEmpty, !written.isEmpty else { return Result(words: heard, followsScript: false, coverage: 0) }
        let heardKeys = heard.map { WordAlignment.key($0.text) }
        let writtenKeys = written.map(WordAlignment.key)
        let pairs = WordAlignment.matches(heardKeys, writtenKeys)
        let coverage = Double(pairs.count) / Double(heard.count)
        let follows = heard.count >= followingMinimumWords && pairs.count >= followingMinimumMatches && coverage >= followingCoverage
        let anchors = follows ? trusted(pairs, keys: heardKeys) : WordAlignment.reliable(pairs, keys: heardKeys)

        var words: [CaptionWord] = []
        var heardFrom = 0
        var writtenFrom = 0
        let end = WordAlignment.Match(first: heard.count, second: written.count)
        for anchor in anchors + [end] {
            guard anchor.first >= heardFrom, anchor.second >= writtenFrom else { continue }
            words += corrected(
                Array(heard[heardFrom..<anchor.first]), toward: Array(written[writtenFrom..<anchor.second]), following: follows
            )
            if anchor.first < heard.count {
                var word = heard[anchor.first]
                word.text = written[anchor.second]
                words.append(word)
            }
            heardFrom = anchor.first + 1
            writtenFrom = anchor.second + 1
        }
        return Result(words: words, followsScript: follows, coverage: coverage)
    }

    /// The matches to trust in a take read from the script: the reliable ones, and a short word
    /// whose neighbor in the script and in the voice has as many words between them (the two
    /// agree on the structure, so it isn't a chance match).
    static func trusted(_ pairs: [WordAlignment.Match], keys: [String]) -> [WordAlignment.Match] {
        let reliable = Set(WordAlignment.reliable(pairs, keys: keys).map(\.first))
        return pairs.enumerated().filter { index, pair in
            if reliable.contains(pair.first) { return true }
            func agrees(with other: WordAlignment.Match?) -> Bool {
                guard let other else { return false }
                let heardGap = abs(pair.first - other.first) - 1
                let writtenGap = abs(pair.second - other.second) - 1
                return heardGap == writtenGap && heardGap <= longestGap - 1
            }
            return agrees(with: index > 0 ? pairs[index - 1] : nil) || agrees(with: index + 1 < pairs.count ? pairs[index + 1] : nil)
        }
        .map(\.element)
    }

    // MARK: - Between the words that line up

    /// The heard words between two matches, written as the script has them when they are nearly the
    /// same words. Nothing changes when the voice and the script say different things there.
    private static func corrected(_ heard: [CaptionWord], toward written: [String], following: Bool) -> [CaptionWord] {
        guard !heard.isEmpty, !written.isEmpty, heard.count <= longestGap, written.count <= longestGap else { return heard }
        let wordLimit = following ? similarity.following : similarity.improvised
        if heard.count == written.count {
            return zip(heard, written).map { word, spelling in
                var word = word
                if isNearlyTheSame(word.text, spelling, limit: wordLimit) { word.text = spelling }
                return word
            }
        }
        // The same letters split into more or fewer words ("news paper" / "newspaper").
        let heardLetters = heard.map { WordAlignment.key($0.text) }.joined()
        let writtenLetters = written.map(WordAlignment.key).joined()
        guard stretchLetters.contains(heardLetters.count), stretchLetters.contains(writtenLetters.count),
              abs(heardLetters.count - writtenLetters.count) <= 1,
              !hasDigit(heardLetters), !hasDigit(writtenLetters),
              ratio(heardLetters, writtenLetters) >= (following ? stretchSimilarity.following : stretchSimilarity.improvised),
              let first = heard.first, let last = heard.last else { return heard }
        return share(written, over: TimeSpan(start: first.start, end: max(first.start, last.end)))
    }

    /// Whether the heard word is the script's word with a slip or two.
    private static func isNearlyTheSame(_ heard: String, _ written: String, limit: Double) -> Bool {
        let heardKey = WordAlignment.key(heard)
        let writtenKey = WordAlignment.key(written)
        guard !hasDigit(heardKey), !hasDigit(writtenKey) else { return false }
        let unspaced = WordSegmenter.containsUnspacedScript(heardKey) || WordSegmenter.containsUnspacedScript(writtenKey)
        let least = unspaced ? minimumLetters.unspaced : minimumLetters.spaced
        guard heardKey.count >= least, writtenKey.count >= least else { return false }
        return ratio(heardKey, writtenKey) >= limit
    }

    /// `words` one after the other over `span`, each as long as its share of the letters. The time
    /// is a guess, so the words are marked estimated.
    private static func share(_ words: [String], over span: TimeSpan) -> [CaptionWord] {
        let weights = words.map { Double(max(1, WordAlignment.key($0).count)) }
        let total = weights.reduce(0, +)
        var cursor = span.start
        return zip(words, weights).map { word, weight in
            let end = cursor + span.duration * weight / total
            defer { cursor = end }
            return CaptionWord(text: word, start: cursor, end: end, isEstimated: true)
        }
    }

    private static func hasDigit(_ text: String) -> Bool {
        text.contains(where: \.isNumber)
    }

    // MARK: - Similarity

    /// How alike two words are, 0 to 1: one minus the edits it takes to turn one into the other
    /// over the longer one's length.
    static func ratio(_ first: String, _ second: String) -> Double {
        let a = Array(first)
        let b = Array(second)
        guard !a.isEmpty || !b.isEmpty else { return 1 }
        guard !a.isEmpty, !b.isEmpty else { return 0 }
        var previous = Array(0...b.count)
        for i in 1...a.count {
            var row = [i] + [Int](repeating: 0, count: b.count)
            for j in 1...b.count {
                row[j] = a[i - 1] == b[j - 1] ? previous[j - 1] : min(previous[j - 1], previous[j], row[j - 1]) + 1
            }
            previous = row
        }
        return 1 - Double(previous[b.count]) / Double(max(a.count, b.count))
    }
}
