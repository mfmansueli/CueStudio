//
//  ReadTime.swift
//  Cue Studio
//

import Foundation

/// Reading-time estimates for scripts. Cue markers like `[pause]` are not spoken, so they don't count.
nonisolated enum ReadTime {
    /// Pace at 1.0× prompter speed. Calibrated so the default speed (`naturalSpeed`) lands on a
    /// natural on-camera pace of about 150 words a minute. Scrolling and every estimate in the app
    /// use this one constant.
    static let wordsPerMinuteAtOneX: Double = 215

    /// Default prompter speed: 0.7× ≈ 150 words a minute.
    static let naturalSpeed: Double = 0.7

    static func wordCount(in text: String) -> Int {
        CueParser.stripCues(text)
            .split(whereSeparator: { $0.isWhitespace || $0.isNewline })
            .count
    }

    /// Words read aloud per minute at a prompter speed.
    static func wordsPerMinute(speed: Double) -> Double {
        wordsPerMinuteAtOneX * max(speed, 0.1)
    }

    /// Seconds needed to read `text` aloud at the given prompter speed.
    static func seconds(for text: String, speed: Double = naturalSpeed) -> TimeInterval {
        Double(wordCount(in: text)) / (wordsPerMinute(speed: speed) / 60)
    }

    /// Roughly how many words fit in `seconds` at the given speed. Used to brief the AI on length.
    static func words(for seconds: TimeInterval, speed: Double = naturalSpeed) -> Int {
        Int((seconds * wordsPerMinute(speed: speed) / 60).rounded())
    }
}
