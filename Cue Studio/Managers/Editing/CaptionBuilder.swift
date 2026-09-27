//
//  CaptionBuilder.swift
//  Cue Studio
//

import Foundation

/// Turns what was said into short captions. The words come from the script (so spelling matches
/// what the creator wrote) and the timing from the transcription of the take. Pure.
nonisolated enum CaptionBuilder {
    /// Words per caption, so each one reads at a glance.
    static let maximumWords = 5

    /// Captions from the transcription's timing, with each heard word replaced by the script's
    /// spelling when they match.
    static func captions(heard: [TimedWord], script: String) -> [CaptionCue] {
        let scriptWords = CueParser.stripCues(script).split(whereSeparator: \.isWhitespace).map(String.init)
        var scriptIndex = 0
        let words = heard.map { word -> TimedWord in
            // Look a few words ahead in the script for the heard word; keep the script's spelling.
            let window = scriptWords[min(scriptIndex, scriptWords.count)..<min(scriptIndex + 4, scriptWords.count)]
            if let offset = window.firstIndex(where: { normalized($0) == normalized(word.text) }) {
                scriptIndex = offset + 1
                return TimedWord(text: scriptWords[offset], start: word.start, end: word.end)
            }
            return word
        }
        return group(words)
    }

    /// Without a transcription (no speech model for the language), the script is spread evenly
    /// over the take.
    static func captions(script: String, duration: TimeInterval) -> [CaptionCue] {
        let words = CueParser.stripCues(script).split(whereSeparator: \.isWhitespace).map(String.init)
        guard !words.isEmpty, duration > 0 else { return [] }
        let step = duration / Double(words.count)
        let timed = words.enumerated().map { index, word in
            TimedWord(text: word, start: Double(index) * step, end: Double(index + 1) * step)
        }
        return group(timed)
    }

    /// Groups words into captions, breaking after sentences and long pauses.
    static func group(_ words: [TimedWord]) -> [CaptionCue] {
        var cues: [CaptionCue] = []
        var current: [TimedWord] = []
        func flush() {
            guard let first = current.first, let last = current.last else { return }
            cues.append(CaptionCue(text: current.map(\.text).joined(separator: " "), start: first.start, end: last.end))
            current = []
        }
        for word in words {
            if let last = current.last, word.start - last.end > 0.6 { flush() }
            current.append(word)
            let endsSentence = word.text.last.map { ".!?".contains($0) } ?? false
            if current.count >= maximumWords || endsSentence { flush() }
        }
        flush()
        return cues
    }

    private static func normalized(_ word: String) -> String {
        word.lowercased()
            .folding(options: [.diacriticInsensitive], locale: nil)
            .filter { $0.isLetter || $0.isNumber }
    }
}
