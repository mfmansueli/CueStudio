//
//  ReadTime.swift
//  Cue Studio
//

import Foundation

/// Reading-time estimates for scripts. Cue markers like `[pause]` are not spoken, so they don't count.
nonisolated enum ReadTime {
    /// Comfortable on-camera pace at 1.0× prompter speed.
    static let baseWordsPerMinute: Double = 150

    static func wordCount(in text: String) -> Int {
        CueParser.stripCues(text)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }

    /// Seconds needed to read `text` aloud at the given prompter speed.
    static func seconds(for text: String, speed: Double = 1) -> TimeInterval {
        let wordsPerSecond = baseWordsPerMinute * max(speed, 0.1) / 60
        return Double(wordCount(in: text)) / wordsPerSecond
    }

    /// Roughly how many words fit in `seconds` at the given speed. Used to brief the AI on length.
    static func words(for seconds: TimeInterval, speed: Double = 1) -> Int {
        Int((seconds * baseWordsPerMinute * speed / 60).rounded())
    }
}
