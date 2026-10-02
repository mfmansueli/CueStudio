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
/// punctuation (`ScriptSpelling`): to heard words it lines up with reliably, and, when the take was
/// read from it, also to the recognizer's near misses, so a different number, a negation or another
/// word is never replaced by what was written. Nothing is ever spread over the take when nothing
/// was heard.
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
    /// - Parameter language: what was heard, so the script is cut into words the same way.
    static func captions(heard: [CaptionWord], script: String, language: CueLanguage? = nil) -> [CaptionCue] {
        group(aligned(heard: withoutContinuations(heard), script: script, language: language))
    }

    /// `heard` without the ellipses the recognizer puts where speech goes on in the next stretch:
    /// they say nothing the voice said, and a line shouldn't end "…" because the next one follows.
    /// A word that was only an ellipsis goes. The script's own punctuation is never touched.
    static func withoutContinuations(_ heard: [CaptionWord]) -> [CaptionWord] {
        heard.compactMap { word in
            var word = word
            word.text = CaptionText.withoutContinuation(word.text)
            return word.text.isEmpty ? nil : word
        }
    }

    /// `heard` with the script's spelling and punctuation where the take follows it (see
    /// `ScriptSpelling`): the same words, in the same order, in their own times.
    static func aligned(heard: [CaptionWord], script: String, language: CueLanguage? = nil) -> [CaptionWord] {
        ScriptSpelling.apply(to: heard, script: script, language: language).words
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
            if let last = current.last, last.isEstimated,
               last.start != word.start || last.end != word.end { flush() }
            if let last = current.last, word.start - last.end > pauseBreak { flush() }
            current.append(word)
            let texts = current.map(\.text)
            let unspaced = WordSegmenter.containsUnspacedScript(word.text)
            let isFull = unspaced
                ? CaptionText.length(texts) >= maximumUnspacedCharacters
                : current.count >= maximumWords || CaptionText.length(texts) >= maximumCharacters
            if !word.isEstimated, isFull || endsSentence(word.text) { flush() }
        }
        flush()
        return cues
    }

    private static func endsSentence(_ word: String) -> Bool {
        guard let last = word.last else { return false }
        return ".!?。！？…؟।".contains(last)
    }
}
