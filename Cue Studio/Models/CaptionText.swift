//
//  CaptionText.swift
//  Cue Studio
//

import Foundation

/// Words to caption text and back, for languages written with spaces and without (Japanese,
/// Chinese, Thai): no space is put between two words written without them.
nonisolated enum CaptionText {
    /// The words as one line.
    static func joined(_ words: [String]) -> String {
        var line = ""
        for word in words where !word.isEmpty {
            if let last = line.unicodeScalars.last, let first = word.unicodeScalars.first,
               !(WordSegmenter.isUnspaced(last) && WordSegmenter.isUnspaced(first)) {
                line += " "
            }
            line += word
        }
        return line
    }

    /// A line split into words: at spaces, and runs written without spaces into dictionary words
    /// that keep their punctuation (`WordTokenizer.displayWords`).
    static func words(in line: String, language: CueLanguage? = nil) -> [String] {
        WordTokenizer.displayWords(in: line, language: language)
    }

    /// How long a line reads, in characters (spaces left out), for breaking lines evenly.
    static func length(_ words: [String]) -> Int {
        words.reduce(0) { $0 + $1.count }
    }

    /// `word` without the ellipsis a recognizer ends a stretch of speech with when the sentence
    /// carries on in the next one ("interessante..." → "interessante"). Empty when the word was
    /// only the ellipsis. A single period, a comma or a question mark stays, and so does an
    /// ellipsis the creator wrote (corrections never go through here).
    static func withoutContinuation(_ word: String) -> String {
        var end = word.endIndex
        var dots = 0
        while end > word.startIndex {
            let previous = word.index(before: end)
            if word[previous] == "…" {
                end = previous
                dots = 0
            } else if word[previous] == "." {
                end = previous
                dots += 1
            } else {
                break
            }
        }
        // Dots alone are a period; two or more (or a "…" among them) are a continuation.
        let trailing = word[end...]
        guard trailing.contains("…") || dots >= 2 else { return word }
        return String(word[..<end])
    }
}
