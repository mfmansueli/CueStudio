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
        group(attachingMarks(aligned(heard: withoutContinuations(heard), script: script, language: language)))
    }

    /// `heard` with the punctuation the recognizer hears as a word of its own in Japanese and Chinese ("します" "。") joined to
    /// the word it belongs to, in that word's time: a line never lights a lone "。", and no space goes before it. An opening
    /// mark ("「", "“") joins the word after it. A pause mark heard after a word that already ends in one (the script's "。"
    /// then the recognizer's "，") goes: the script's punctuation stands. Measured on an iPhone (`ScriptFontDeviceTests`).
    static func attachingMarks(_ heard: [CaptionWord]) -> [CaptionWord] {
        var words: [CaptionWord] = []
        var opening = ""
        for var word in heard {
            let text = word.text.trimmingCharacters(in: .whitespaces)
            if isMark(text), text.unicodeScalars.allSatisfy(opens) {
                opening += text
                continue
            }
            if isMark(text), var last = words.popLast() {
                let pauses = text.unicodeScalars.allSatisfy(isPause) && last.text.unicodeScalars.last.map(isPause) == true
                last.text += pauses ? opening : opening + text
                opening = ""
                words.append(last)
                continue
            }
            word.text = opening + word.text
            opening = ""
            words.append(word)
        }
        if !opening.isEmpty, var last = words.popLast() {
            last.text += opening
            words.append(last)
        }
        return words
    }

    /// Only marks written against a word: CJK and full-width punctuation, and curly quotes.
    private static func isMark(_ text: String) -> Bool {
        !text.isEmpty && text.unicodeScalars.allSatisfy { scalar in
            let punctuation: [Unicode.GeneralCategory] = [
                .openPunctuation, .closePunctuation, .initialPunctuation, .finalPunctuation, .otherPunctuation,
            ]
            guard punctuation.contains(scalar.properties.generalCategory) else { return false }
            switch scalar.value {
            case 0x3001...0x303F, 0xFF01...0xFF65, 0x2018...0x201F: return true
            default: return false
            }
        }
    }

    /// A mark that ends a sentence or a clause: "。", "，", "、", "！", "？", "；", "：", or "." "," and their kin.
    private static func isPause(_ scalar: Unicode.Scalar) -> Bool {
        "。，、！？；：．.,!?;:".unicodeScalars.contains(scalar)
    }

    private static func opens(_ scalar: Unicode.Scalar) -> Bool {
        [.openPunctuation, .initialPunctuation].contains(scalar.properties.generalCategory)
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
    /// full. Words that share one time (a recognizer's run of several) are never split and start a new
    /// line after them; words with times of their own, measured or spread over the speech
    /// (`TranscriptTimingCheck`), are grouped alike.
    static func group(_ words: [CaptionWord]) -> [CaptionCue] {
        let words = words.filter { !$0.text.isEmpty }
        var cues: [CaptionCue] = []
        var current: [CaptionWord] = []
        func flush() {
            guard !current.isEmpty else { return }
            cues.append(CaptionCue(words: current))
            current = []
        }
        for (index, word) in words.enumerated() {
            if let last = current.last, last.isEstimated, !sharesTime(last, word), index >= 2, sharesTime(words[index - 2], last) { flush() }
            if let last = current.last, word.start - last.end > pauseBreak { flush() }
            current.append(word)
            let texts = current.map(\.text)
            let unspaced = WordSegmenter.containsUnspacedScript(word.text)
            let isFull = unspaced
                ? CaptionText.length(texts) >= maximumUnspacedCharacters
                : current.count >= maximumWords || CaptionText.length(texts) >= maximumCharacters
            let splitsRun = index + 1 < words.count && sharesTime(words[index + 1], word)
            if !splitsRun, isFull || endsSentence(word.text) { flush() }
        }
        flush()
        return cues
    }

    private static func sharesTime(_ a: CaptionWord, _ b: CaptionWord) -> Bool {
        a.start == b.start && a.end == b.end
    }

    private static func endsSentence(_ word: String) -> Bool {
        guard let last = word.last else { return false }
        return ".!?。！？…؟।".contains(last)
    }
}
