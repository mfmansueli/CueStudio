//
//  ScriptRetakeDetector.swift
//  Cue Studio
//

import Foundation

/// Finds the lines of the script the creator said more than once (plan §10): each time the opening of a line is heard again
/// before the next line starts, the take holds another try at it. Every try becomes a suggestion of its group
/// (`CleanUpSuggestion.Attempt`), never sure: the creator listens and picks the one to keep, and nothing is marked to go until
/// then. The last try is not assumed to be the best.
///
/// It tolerates what recognition and improvising do: a line's opening matches with one word of its first four heard
/// differently, words are compared folded (`WordTokenizer.key`: case, accents, widths), and what is said between the tries
/// (improvised words, "sorry", a filler) belongs to the try it follows. A line the script itself says more than once is left
/// alone (its repeats may be meant), and so are lines shorter than `shortestLine` words (too common to tell a try from a
/// repeat). Pure, so it is tested with made-up words.
nonisolated enum ScriptRetakeDetector {
    /// Words of a line's opening that are compared.
    static let openingWords = 4
    /// Lines with fewer words aren't followed.
    static let shortestLine = 3
    /// Two tries at a line start at most this far apart.
    static let longestRetry: TimeInterval = 40
    /// Below `CleanUpSuggestion.sureConfidence`: never marked to go on its own.
    static let confidence = 0.5
    /// How long before a try's first word its cut starts, and what is kept after the take's last word.
    static let lead: TimeInterval = 0.05
    static let tail: TimeInterval = 0.15

    /// A line of the script: as written, and its words as compared.
    struct Line: Equatable {
        let text: String
        let keys: [String]
    }

    /// The script's lines: its sentences, split at end punctuation and line breaks.
    static func lines(in script: String) -> [Line] {
        var lines: [Line] = []
        var current = ""
        func close() {
            let text = current.trimmingCharacters(in: .whitespacesAndNewlines)
            current = ""
            guard !text.isEmpty else { return }
            let keys = WordTokenizer.words(in: text).map { WordTokenizer.key($0.text) }.filter { !$0.isEmpty }
            if !keys.isEmpty { lines.append(Line(text: text, keys: keys)) }
        }
        for character in script {
            current.append(character)
            if ".!?…。！？\n".contains(character) { close() }
        }
        close()
        return lines
    }

    /// The tries at the lines of `script` said more than once in `words` (in the order said), each a suggestion of its group.
    static func suggestions(in words: [TimedWord], script: String) -> [CleanUpSuggestion] {
        let lines = lines(in: script)
        guard !lines.isEmpty, words.count >= shortestLine else { return [] }
        let keys = words.map { WordTokenizer.key($0.text) }
        let openings = lines.map { opening(of: $0) }
        let heard = openings.map { opening in opening.map { positions(of: $0, in: keys) } ?? [] }
        var result: [CleanUpSuggestion] = []
        var covered: [ClosedRange<Int>] = []
        for (index, line) in lines.enumerated() {
            guard let opening = openings[index],
                  openings.filter({ $0 == opening }).count == 1 else { continue }
            let tries = heard[index]
            guard tries.count >= 2 else { continue }
            // Where the take moves on: the next time any other line opens after the last try.
            let others = heard.enumerated().filter { $0.offset != index && openings[$0.offset] != opening }.flatMap(\.element)
            let groups = consecutive(tries, words: words, others: others)
            for group in groups {
                guard let first = group.first, let last = group.last else { continue }
                let lastEnd = min(last + line.keys.count, others.filter { $0 > last }.min() ?? words.count, words.count) - 1
                let range = first...max(lastEnd, last)
                // A line whose tries fall inside an earlier line's tries is part of those.
                guard !covered.contains(where: { $0.overlaps(range) }) else { continue }
                covered.append(range)
                let id = UUID()
                for (number, start) in group.enumerated() {
                    let end = number + 1 < group.count ? group[number + 1] - 1 : max(lastEnd, start)
                    result.append(CleanUpSuggestion(
                        kind: .retake, span: span(of: words, from: start, through: end), text: TimedWord.text(of: words, from: start, through: end),
                        confidence: confidence,
                        attempt: CleanUpSuggestion.Attempt(group: id, number: number + 1, count: group.count, line: line.text)
                    ))
                }
            }
        }
        return result.sorted { $0.span.start < $1.span.start }
    }

    // MARK: - Private

    /// The words a line is recognized by: its first `openingWords`; nil for a line too short to follow.
    private static func opening(of line: Line) -> [String]? {
        guard line.keys.count >= shortestLine else { return nil }
        return Array(line.keys.prefix(openingWords))
    }

    /// Where `opening` is heard in `keys`: its first word exactly, and at most one of the others heard differently. Matches
    /// never overlap.
    private static func positions(of opening: [String], in keys: [String]) -> [Int] {
        var found: [Int] = []
        var index = 0
        while index + opening.count <= keys.count {
            let same = zip(opening, keys[index..<index + opening.count]).filter { $0 == $1 }.count
            if keys[index] == opening[0], same >= opening.count - 1 {
                found.append(index)
                index += opening.count
            } else {
                index += 1
            }
        }
        return found
    }

    /// The tries split where another line opens between two of them, or where they start too far apart: each part a group of
    /// two or more tries said one after the other.
    private static func consecutive(_ tries: [Int], words: [TimedWord], others: [Int]) -> [[Int]] {
        var groups: [[Int]] = []
        var current: [Int] = []
        for start in tries {
            if let previous = current.last,
               others.contains(where: { $0 > previous && $0 < start }) || words[start].start - words[previous].start > longestRetry {
                groups.append(current)
                current = []
            }
            current.append(start)
        }
        groups.append(current)
        return groups.filter { $0.count >= 2 }
    }

    /// What taking out `first` through `last` removes: from a moment before the first word (never into the word before it) to a
    /// moment before the word after the last, or a short tail at the end of the take.
    private static func span(of words: [TimedWord], from first: Int, through last: Int) -> TimeSpan {
        let start = max(first > 0 ? words[first - 1].end : 0, words[first].start - lead)
        let end = last + 1 < words.count ? max(words[last].end, words[last + 1].start - lead) : words[last].end + tail
        return TimeSpan(start: max(0, start), end: max(start, end))
    }
}
