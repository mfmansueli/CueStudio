//
//  MixedLanguageMerge.swift
//  Cue Studio
//

import Foundation

/// One take heard in several languages, put back together by what the script says.
///
/// A recognizer listens in one language: an English opening read into a Portuguese recognizer comes
/// out as Portuguese-sounding words that mean nothing, and the Portuguese rest read into an English
/// one is no better. So a take whose script uses two languages is heard in both, and each stretch
/// of the script is taken from the recognizer whose words line up with it, in its own language.
/// Nothing is guessed from the sound: the creator read the script, so the recognizer that hears
/// those words is the one that heard them in the right language.
///
/// For each stretch of the script (`ScriptLanguageRuns`) the recognizer that lines up best with it
/// wins, as long as it lines up at all; the stretch's moment in the take is where those words were
/// heard. Words said in a moment a stretch won come from its recognizer; the rest of the take comes
/// from the main one. A take nobody lines up with (improvised, or not read from the script) is the
/// main recognizer's, as before.
nonisolated enum MixedLanguageMerge {
    /// What one recognizer heard.
    struct Heard: Sendable {
        let code: String
        let words: [TimedWord]
    }

    /// Share of a stretch's words a recognizer must line up with to win it.
    static let minimumScore = 0.4
    /// Fewest words a recognizer must line up with in a stretch to win it.
    static let minimumMatches = 2
    /// How far a stretch's moment reaches past the words that lined up, for the words around them.
    static let edge: TimeInterval = 0.3
    /// What a stretch gains when it is heard in the language it is written in, so a tie goes to
    /// the recognizer for that language.
    static let languageBonus = 0.05

    /// The words of the take: `primary`'s code names the main recognizer.
    static func merge(_ heard: [Heard], primary: String, reading: ScriptLanguageRuns.Reading) -> [TimedWord] {
        guard let main = heard.first(where: { $0.code == primary }) ?? heard.first else { return [] }
        guard heard.count > 1, !reading.runs.isEmpty else { return main.words }
        let windows = windows(of: heard, reading: reading)
        guard !windows.isEmpty else { return main.words }
        let ranges = windows.enumerated().map { index, window in
            let before = index > 0 ? (window.start - windows[index - 1].end) / 2 : edge
            let after = index + 1 < windows.count ? (windows[index + 1].start - window.end) / 2 : edge
            return (window.start - min(edge, max(0, before)))...(window.end + min(edge, max(0, after)))
        }
        var merged: [TimedWord] = []
        for (window, range) in zip(windows, ranges) {
            merged += heard[window.source].words.filter { range.contains(midpoint($0)) }
        }
        merged += main.words.filter { word in !ranges.contains { $0.contains(midpoint(word)) } }
        return merged.sorted { $0.start < $1.start }
    }

    // MARK: - Where each recognizer wins

    private struct Window {
        let source: Int
        var start: TimeInterval
        var end: TimeInterval
    }

    /// The moment of each stretch the script's words were heard in, by the recognizer that lined up
    /// with it best, in order and never overlapping.
    private static func windows(of heard: [Heard], reading: ScriptLanguageRuns.Reading) -> [Window] {
        let written = reading.words.map(WordAlignment.key)
        let found = heard.map { WordAlignment.matches($0.words.map { WordAlignment.key($0.text) }, written) }
        var windows: [Window] = []
        for run in reading.runs {
            let size = run.words.count
            var best: (score: Double, window: Window)?
            for (index, pairs) in found.enumerated() {
                let inside = pairs.filter { run.words.contains($0.second) }
                guard inside.count >= minimumMatches, let first = inside.first, let last = inside.last else { continue }
                let score = Double(inside.count) / Double(size) + (heard[index].code == run.code ? languageBonus : 0)
                guard score >= minimumScore, score > (best?.score ?? 0) else { continue }
                let words = heard[index].words
                best = (score, Window(source: index, start: words[first.first].start, end: max(words[first.first].start, words[last.first].end)))
            }
            if let best { windows.append(best.window) }
        }
        return separated(windows.sorted { $0.start < $1.start })
    }

    /// Windows that touch are cut halfway; one inside another is dropped.
    private static func separated(_ sorted: [Window]) -> [Window] {
        var result: [Window] = []
        for var window in sorted {
            if var last = result.last {
                if window.end <= last.end { continue }
                if window.start < last.end {
                    let middle = (window.start + last.end) / 2
                    last.end = middle
                    window.start = middle
                    result[result.count - 1] = last
                }
            }
            result.append(window)
        }
        return result
    }

    private static func midpoint(_ word: TimedWord) -> TimeInterval {
        (word.start + word.end) / 2
    }
}
