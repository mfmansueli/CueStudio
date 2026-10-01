//
//  CaptionRevision.swift
//  Cue Studio
//

import Foundation

/// Corrections to caption lines: new words, a split, a merge. Times the voice gave are kept
/// wherever the words still line up; anything new gets a time between its neighbors, marked as a
/// guess, and the line says its timing needs a look, so a word-by-word effect never follows a time
/// that isn't real.
nonisolated enum CaptionRevision {
    /// `cue` saying `text`. A line with word times keeps the times of the words that still match
    /// and guesses the rest; a line timed as a whole keeps its time.
    static func retimed(_ cue: CaptionCue, text: String) -> CaptionCue {
        var revised = cue
        revised.text = text
        revised.isRevised = true
        guard !cue.words.isEmpty else { return revised }
        let newWords = CaptionText.words(in: text)
        guard !newWords.isEmpty else {
            revised.words = []
            return revised
        }
        let pairs = WordAlignment.matches(newWords.map(WordAlignment.key), cue.words.map { WordAlignment.key($0.text) })
        var kept: [Int: CaptionWord] = [:]
        for pair in pairs { kept[pair.first] = cue.words[pair.second] }
        var words: [CaptionWord] = []
        var guessed = false
        for (index, word) in newWords.enumerated() {
            if let old = kept[index] {
                words.append(CaptionWord(text: word, start: old.start, end: old.end, isEstimated: old.isEstimated))
            } else {
                guessed = true
                // Between the word before (or the line's start) and the next kept one (or its end).
                let from = words.last?.end ?? cue.start
                let nextKept = (index + 1..<newWords.count).lazy.compactMap { kept[$0] }.first
                let until = max(from, nextKept?.start ?? cue.end)
                let unkept = (index..<newWords.count).prefix { kept[$0] == nil }.count
                let step = (until - from) / Double(max(1, unkept))
                words.append(CaptionWord(text: word, start: from, end: from + step, isEstimated: true))
            }
        }
        revised.words = words
        revised.needsTimingReview = cue.needsTimingReview || guessed
        return revised
    }

    /// `cue` split before its word at `index` (or, for a line without word times, before that
    /// word of its text, the time shared by length). Nil when either side would be empty.
    static func split(_ cue: CaptionCue, beforeWord index: Int) -> (CaptionCue, CaptionCue)? {
        if !cue.words.isEmpty {
            guard index > 0, index < cue.words.count else { return nil }
            let head = Array(cue.words[..<index])
            let tail = Array(cue.words[index...])
            var first = cue
            first.words = head
            first.text = CaptionText.joined(head.map(\.text))
            first.end = head.last?.end ?? cue.end
            var second = CaptionCue(
                text: CaptionText.joined(tail.map(\.text)), start: tail.first?.start ?? first.end, end: cue.end, words: tail,
                origin: cue.origin, isRevised: true, needsTimingReview: cue.needsTimingReview
            )
            second.sourceID = cue.sourceID
            second.start = max(second.start, first.end)
            first.isRevised = true
            return (first, second)
        }
        let words = CaptionText.words(in: cue.text)
        guard index > 0, index < words.count else { return nil }
        let head = Array(words[..<index])
        let tail = Array(words[index...])
        // No word times: the line's time is shared by how much each side says.
        let share = Double(CaptionText.length(head)) / Double(max(1, CaptionText.length(words)))
        let cut = cue.start + (cue.end - cue.start) * share
        var first = cue
        first.text = CaptionText.joined(head)
        first.end = cut
        first.isRevised = true
        var second = CaptionCue(
            text: CaptionText.joined(tail), start: cut, end: cue.end, origin: cue.origin, isRevised: true, needsTimingReview: true
        )
        second.sourceID = cue.sourceID
        first.needsTimingReview = true
        return (first, second)
    }

    /// The line's words: its timed words, or its text's.
    static func words(of cue: CaptionCue) -> [String] {
        cue.words.isEmpty ? CaptionText.words(in: cue.text) : cue.words.map(\.text)
    }

    /// Where to split `cue` for a cut at `time` (seconds of the recording): before the first word
    /// that ends after it; without word times, by how far into the line it is. Always leaves a
    /// word on each side (the line needs two).
    static func splitIndex(of cue: CaptionCue, atSource time: TimeInterval) -> Int {
        let count = words(of: cue).count
        guard count > 1 else { return 1 }
        let index: Int
        if cue.words.isEmpty {
            let progress = (time - cue.start) / max(0.001, cue.end - cue.start)
            index = Int((progress * Double(count)).rounded())
        } else {
            index = cue.words.firstIndex { ($0.start + $0.end) / 2 >= time } ?? count
        }
        return min(max(index, 1), count - 1)
    }

    /// Two lines as one, from the start of the first to the end of the second.
    static func merged(_ first: CaptionCue, _ second: CaptionCue) -> CaptionCue {
        var merged = first
        merged.text = CaptionText.joined([first.text, second.text])
        merged.start = min(first.start, second.start)
        merged.end = max(first.end, second.end)
        merged.words = first.words.isEmpty || second.words.isEmpty ? [] : first.words + second.words
        merged.isRevised = true
        merged.needsTimingReview = first.needsTimingReview || second.needsTimingReview
        return merged
    }
}
