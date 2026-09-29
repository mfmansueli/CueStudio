//
//  CaptionBuilder.swift
//  Cue Studio
//

import Foundation

/// Caption lines from what was heard in the take.
///
/// The voice decides what is said and when: every heard word is kept, in its own time, and words of
/// the script that weren't said never appear (an improvised line shows as said, a skipped one is
/// left out, a word said twice shows twice until it is cut). The script only lends its spelling and
/// punctuation to heard words it lines up with reliably (the same word, in order, inside a run of
/// two or more, or long enough not to match by chance), so a different number, a negation or
/// another word is never replaced by what was written. Nothing is ever spread over the take when
/// nothing was heard.
nonisolated enum CaptionBuilder {
    /// Words per line at most, so each one reads at a glance.
    static let maximumWords = 5
    /// Letters per line at most, for long words.
    static let maximumCharacters = 30
    /// Letters per line at most in languages written without spaces (Japanese, Chinese, Thai).
    static let maximumUnspacedCharacters = 16
    /// A silence this long starts a new line.
    static let pauseBreak: TimeInterval = 0.6
    /// Lines from `heard`, with the script's spelling where it reliably matches.
    static func captions(heard: [CaptionWord], script: String) -> [CaptionCue] {
        group(aligned(heard: heard, script: script))
    }

    /// `heard` with the script's spelling and punctuation on the words that reliably match it.
    /// Same words, same times, same order.
    static func aligned(heard: [CaptionWord], script: String) -> [CaptionWord] {
        let written = CaptionText.words(in: CueParser.stripCues(script))
        guard !heard.isEmpty, !written.isEmpty else { return heard }
        var result = heard
        let keys = heard.map { WordAlignment.key($0.text) }
        let pairs = WordAlignment.matches(keys, written.map(WordAlignment.key))
        for pair in WordAlignment.reliable(pairs, keys: keys) {
            result[pair.first].text = written[pair.second]
        }
        return result
    }

    /// Words grouped into lines: a new line after a sentence ends, after a pause, and when a line is
    /// full.
    static func group(_ words: [CaptionWord]) -> [CaptionCue] {
        var cues: [CaptionCue] = []
        var current: [CaptionWord] = []
        func flush() {
            guard !current.isEmpty else { return }
            cues.append(CaptionCue(words: current))
            current = []
        }
        for word in words where !word.text.isEmpty {
            if let last = current.last, word.start - last.end > pauseBreak { flush() }
            current.append(word)
            let texts = current.map(\.text)
            let unspaced = WordSegmenter.containsUnspacedScript(word.text)
            let isFull = unspaced
                ? CaptionText.length(texts) >= maximumUnspacedCharacters
                : current.count >= maximumWords || CaptionText.length(texts) >= maximumCharacters
            if isFull || endsSentence(word.text) { flush() }
        }
        flush()
        return cues
    }

    private static func endsSentence(_ word: String) -> Bool {
        guard let last = word.last else { return false }
        return ".!?。！？…؟।".contains(last)
    }
}
