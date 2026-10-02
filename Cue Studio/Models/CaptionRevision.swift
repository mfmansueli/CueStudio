//
//  CaptionRevision.swift
//  Cue Studio
//

import Foundation

/// Corrections to caption lines: new words, a split, a merge, a move. A correction changes what a
/// line says or where it sits, never how it looks: the line keeps its identity, so the style
/// (preset, colors, the word that lights up as it is said) stays on it. Times the voice gave are
/// kept wherever the words still line up; words that replace or join others share the stretch the
/// voice spent on what they replace, so a word-by-word effect keeps following the voice. Only a
/// word with no stretch of the voice to stand on is a guess, and the line then says its timing
/// needs a look.
nonisolated enum CaptionRevision {
    /// The least a new word is given, in seconds, when it has to take its room from a neighbor.
    private static let minimumWordDuration: TimeInterval = 0.08

    /// `cue` saying `text`. A line with word times keeps the times of the words that still match;
    /// words that replace others (a spelling fix, a different word) take the place of the ones they
    /// replace, and extra words share it, by length; a line timed as a whole keeps its time.
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
        var words: [CaptionWord] = []
        var guessed = false
        var newFrom = 0
        var oldFrom = 0
        for anchor in pairs + [WordAlignment.Match(first: newWords.count, second: cue.words.count)] {
            let fresh = Array(newWords[newFrom..<max(newFrom, anchor.first)])
            let replaced = Array(cue.words[oldFrom..<max(oldFrom, anchor.second)])
            if !fresh.isEmpty {
                let after = anchor.second < cue.words.count ? cue.words[anchor.second].start : cue.end
                var (stretch, isGuess) = room(for: replaced, before: words.last?.end ?? cue.start, after: after, needs: fresh.count)
                // Words said back to back: a new one takes the second half of the word before it.
                if isGuess, let last = words.last, last.end - last.start >= 2 * minimumWordDuration * Double(fresh.count) {
                    let middle = (last.start + last.end) / 2
                    stretch = TimeSpan(start: middle, end: last.end)
                    words[words.count - 1] = CaptionWord(text: last.text, start: last.start, end: middle, isEstimated: last.isEstimated)
                    isGuess = false
                }
                guessed = guessed || isGuess
                words += share(fresh, over: stretch, isEstimated: isGuess || replaced.contains(where: \.isEstimated))
            }
            if anchor.first < newWords.count {
                let old = cue.words[anchor.second]
                words.append(CaptionWord(text: newWords[anchor.first], start: old.start, end: old.end, isEstimated: old.isEstimated))
            }
            newFrom = anchor.first + 1
            oldFrom = anchor.second + 1
        }
        revised.words = words
        revised.needsTimingReview = cue.needsTimingReview || guessed
        return revised
    }

    /// Where `needs` new words go: the stretch of the words they replace, else the silence between
    /// their neighbors. No room at all is a guess.
    private static func room(
        for replaced: [CaptionWord], before: TimeInterval, after: TimeInterval, needs: Int
    ) -> (span: TimeSpan, isGuess: Bool) {
        if let first = replaced.first, let last = replaced.last {
            return (TimeSpan(start: first.start, end: max(first.start, last.end)), false)
        }
        let gap = TimeSpan(start: before, end: max(before, after))
        return (gap, gap.duration < minimumWordDuration * Double(needs))
    }

    /// `words` one after the other over `span`, each as long as its share of the letters.
    private static func share(_ words: [String], over span: TimeSpan, isEstimated: Bool) -> [CaptionWord] {
        let weights = words.map { Double(max(1, $0.count)) }
        let total = weights.reduce(0, +)
        var cursor = span.start
        return zip(words, weights).map { word, weight in
            let end = cursor + span.duration * weight / total
            defer { cursor = end }
            return CaptionWord(text: word, start: cursor, end: end, isEstimated: isEstimated)
        }
    }

    /// `cue` after its start or end moved: the words stay on the voice, folded into the line's new
    /// time when it shrank. The line asks for a look only when a word has no time left.
    static func fitted(_ cue: CaptionCue) -> CaptionCue {
        var fitted = cue
        fitted.words = cue.words.map { word in
            let start = min(max(word.start, cue.start), cue.end)
            let end = min(max(word.end, start), cue.end)
            return CaptionWord(text: word.text, start: start, end: end, isEstimated: word.isEstimated)
        }
        if fitted.words.contains(where: { $0.end - $0.start < 0.02 }) { fitted.needsTimingReview = true }
        return fitted
    }

    /// Lines heard before the recognizer's continuation ellipses were left out, without them. Only
    /// a line that is still as it was heard: whatever the creator typed or corrected stays.
    static func withoutContinuation(_ cue: CaptionCue) -> CaptionCue {
        guard cue.origin == .speech, !cue.isRevised else { return cue }
        var cleaned = cue
        cleaned.words = cue.words.compactMap { word in
            var word = word
            word.text = CaptionText.withoutContinuation(word.text)
            return word.text.isEmpty ? nil : word
        }
        let text = cue.words.isEmpty
            ? CaptionText.joined(CaptionText.words(in: cue.text).map(CaptionText.withoutContinuation))
            : CaptionText.joined(cleaned.words.map(\.text))
        guard !text.isEmpty else { return cue }
        cleaned.text = text
        return cleaned
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
